// SPDX-License-Identifier: GPL-2.0-only
/*
 * Copyright (c) 2022-2024 Qualcomm Innovation Center, Inc. All rights reserved.
 */

#include <linux/module.h>
#include <linux/pm_runtime.h>

#include "iris_firmware.h"
#include "iris_core.h"
#include "iris_hfi_common.h"
#include "iris_vpu_common.h"

/*
 * VPU5 idle power collapse, driven by pc_work.  Enabled by default; set
 * power_collapse=N to pin the VPU powered.
 */
static bool power_collapse = true;
module_param(power_collapse, bool, 0644);
MODULE_PARM_DESC(power_collapse,
		 "Allow SM8150 VPU5 idle power collapse (default Y)");

u32 iris_hfi_get_v4l2_color_primaries(u32 hfi_primaries)
{
	switch (hfi_primaries) {
	case HFI_PRIMARIES_RESERVED:
		return V4L2_COLORSPACE_DEFAULT;
	case HFI_PRIMARIES_BT709:
		return V4L2_COLORSPACE_REC709;
	case HFI_PRIMARIES_BT470_SYSTEM_M:
		return V4L2_COLORSPACE_470_SYSTEM_M;
	case HFI_PRIMARIES_BT470_SYSTEM_BG:
		return V4L2_COLORSPACE_470_SYSTEM_BG;
	case HFI_PRIMARIES_BT601_525:
		return V4L2_COLORSPACE_SMPTE170M;
	case HFI_PRIMARIES_SMPTE_ST240M:
		return V4L2_COLORSPACE_SMPTE240M;
	case HFI_PRIMARIES_BT2020:
		return V4L2_COLORSPACE_BT2020;
	case V4L2_COLORSPACE_DCI_P3:
		return HFI_PRIMARIES_SMPTE_RP431_2;
	default:
		return V4L2_COLORSPACE_DEFAULT;
	}
}

u32 iris_hfi_get_v4l2_transfer_char(u32 hfi_characterstics)
{
	switch (hfi_characterstics) {
	case HFI_TRANSFER_RESERVED:
		return V4L2_XFER_FUNC_DEFAULT;
	case HFI_TRANSFER_BT709:
		return V4L2_XFER_FUNC_709;
	case HFI_TRANSFER_SMPTE_ST240M:
		return V4L2_XFER_FUNC_SMPTE240M;
	case HFI_TRANSFER_SRGB_SYCC:
		return V4L2_XFER_FUNC_SRGB;
	case HFI_TRANSFER_SMPTE_ST2084_PQ:
		return V4L2_XFER_FUNC_SMPTE2084;
	default:
		return V4L2_XFER_FUNC_DEFAULT;
	}
}

u32 iris_hfi_get_v4l2_matrix_coefficients(u32 hfi_coefficients)
{
	switch (hfi_coefficients) {
	case HFI_MATRIX_COEFF_RESERVED:
		return V4L2_YCBCR_ENC_DEFAULT;
	case HFI_MATRIX_COEFF_BT709:
		return V4L2_YCBCR_ENC_709;
	case HFI_MATRIX_COEFF_BT470_SYS_BG_OR_BT601_625:
		return V4L2_YCBCR_ENC_XV601;
	case HFI_MATRIX_COEFF_BT601_525_BT1358_525_OR_625:
		return V4L2_YCBCR_ENC_601;
	case HFI_MATRIX_COEFF_SMPTE_ST240:
		return V4L2_YCBCR_ENC_SMPTE240M;
	case HFI_MATRIX_COEFF_BT2020_NON_CONSTANT:
		return V4L2_YCBCR_ENC_BT2020;
	case HFI_MATRIX_COEFF_BT2020_CONSTANT:
		return V4L2_YCBCR_ENC_BT2020_CONST_LUM;
	default:
		return V4L2_YCBCR_ENC_DEFAULT;
	}
}

int iris_hfi_core_init(struct iris_core *core)
{
	const struct iris_hfi_command_ops *hfi_ops = core->hfi_ops;
	int ret;

	/*
	 * Wait for the VPU5 SYS_INIT response before sending any further
	 * command.  The downstream Venus driver sends its default system
	 * properties later, immediately before SESSION_INIT.
	 */
	if (core->iris_platform_data->legacy_vpu5) {
		dev_info(core->dev,
			 "Iris1 v88: sending SYS_INIT through legacy HFI queue\n");
		return hfi_ops->sys_init(core);
	}

	ret = hfi_ops->sys_init(core);
	if (ret)
		return ret;

	ret = hfi_ops->sys_image_version(core);
	if (ret)
		return ret;

	return hfi_ops->sys_interframe_powercollapse(core);
}

irqreturn_t iris_hfi_isr(int irq, void *data)
{
	struct iris_core *core = data;

	disable_irq_nosync(irq);

	/*
	 * SM8150 VPU5 signals a level-high interrupt.  Clear the source in
	 * the hard IRQ handler, as the legacy Venus driver does.  Deferring
	 * the clear leaves the source asserted during firmware boot because
	 * iris_core_init() owns core->lock while the threaded handler waits.
	 */
	if (core && core->iris_platform_data->legacy_vpu5)
		iris_vpu_clear_interrupt(core);

	return IRQ_WAKE_THREAD;
}

irqreturn_t iris_hfi_isr_handler(int irq, void *data)
{
	struct iris_core *core = data;

	if (!core)
		return IRQ_NONE;

	mutex_lock(&core->lock);
	pm_runtime_mark_last_busy(core->dev);
	if (!core->iris_platform_data->legacy_vpu5)
		iris_vpu_clear_interrupt(core);
	mutex_unlock(&core->lock);

	core->hfi_response_ops->hfi_response_handler(core);

	if (!iris_vpu_watchdog(core, core->intr_status))
		enable_irq(irq);

	return IRQ_HANDLED;
}

/*
 * SM8150 VPU5 power collapse is driven by pc_work instead of runtime PM: a
 * delayed work power-collapses the VPU only when no session is open, and the
 * next user operation resumes it.  Serialising this under core->lock avoids
 * the runtime-PM race that wedged the firmware on resume.
 */
#define IRIS_PC_DELAY_MS	2000

static int iris_pc_enter(struct iris_core *core)
{
	int ret;

	ret = iris_vpu_prepare_pc(core);
	if (ret) {
		dev_dbg(core->dev, "power collapse: prepare failed %d\n", ret);
		return ret;
	}

	ret = iris_set_hw_state(core, false);
	if (ret)
		return ret;

	iris_vpu_power_off(core);
	core->vpu_suspended = true;
	dev_info(core->dev, "VPU entered power collapse\n");

	return 0;
}

static int iris_pc_exit(struct iris_core *core)
{
	const struct iris_hfi_command_ops *ops = core->hfi_ops;
	int ret;

	if (!core->vpu_suspended)
		return 0;

	ret = iris_vpu_power_on(core);
	if (ret)
		goto error;

	ret = iris_set_hw_state(core, true);
	if (ret)
		goto err_power_off;

	ret = iris_vpu_boot_firmware(core);
	if (ret)
		goto err_suspend_hw;

	if (!core->iris_platform_data->legacy_vpu5) {
		ret = ops->sys_interframe_powercollapse(core);
		if (ret)
			goto err_suspend_hw;
	}

	core->vpu_suspended = false;
	dev_info(core->dev, "VPU resumed from power collapse\n");

	return 0;

err_suspend_hw:
	iris_set_hw_state(core, false);
err_power_off:
	iris_vpu_power_off(core);
error:
	dev_err(core->dev, "failed to resume from power collapse\n");

	return -EBUSY;
}

int iris_pc_resume(struct iris_core *core)
{
	int ret = 0;

	if (!core->iris_platform_data->legacy_vpu5 || !power_collapse)
		return 0;

	cancel_delayed_work_sync(&core->pc_work);

	mutex_lock(&core->lock);
	if (core->vpu_suspended)
		ret = iris_pc_exit(core);
	mutex_unlock(&core->lock);

	return ret;
}

void iris_pc_schedule(struct iris_core *core)
{
	if (!core->iris_platform_data->legacy_vpu5 || !power_collapse)
		return;

	if (!list_empty(&core->instances))
		return;

	queue_delayed_work(system_wq, &core->pc_work,
			   msecs_to_jiffies(IRIS_PC_DELAY_MS));
}

void iris_pc_handler(struct work_struct *work)
{
	struct iris_core *core =
		container_of(work, struct iris_core, pc_work.work);
	int ret;

	mutex_lock(&core->lock);
	if (!core->vpu_suspended && list_empty(&core->instances)) {
		ret = iris_pc_enter(core);
		if (ret)
			dev_warn(core->dev,
				 "skip VPU power collapse (%d)\n", ret);
	}
	mutex_unlock(&core->lock);

	if (!core->vpu_suspended)
		iris_pc_schedule(core);
}

int iris_hfi_pm_suspend(struct iris_core *core)
{
	int ret;

	/*
	 * Only the system sleep path reaches this callback: runtime PM is
	 * forbidden on legacy VPU5, and newer hardware keeps its own handling.
	 * With sessions open the VPU must stay powered, so succeed without
	 * touching it to avoid aborting s2idle.
	 */
	if (!list_empty(&core->instances))
		return 0;

	ret = iris_vpu_prepare_pc(core);
	if (ret) {
		pm_runtime_mark_last_busy(core->dev);
		ret = -EAGAIN;
		goto error;
	}

	ret = iris_set_hw_state(core, false);
	if (ret)
		goto error;

	iris_vpu_power_off(core);
	core->vpu_suspended = true;

	return 0;

error:
	dev_err_once(core->dev,
		     "failed to suspend (%d); suppressing repeated messages\n", ret);

	return ret;
}

int iris_hfi_pm_resume(struct iris_core *core)
{
	const struct iris_hfi_command_ops *ops = core->hfi_ops;
	int ret;

	if (!core->vpu_suspended)
		return 0;

	ret = iris_vpu_power_on(core);
	if (ret)
		goto error;

	ret = iris_set_hw_state(core, true);
	if (ret)
		goto err_power_off;

	ret = iris_vpu_boot_firmware(core);
	if (ret)
		goto err_suspend_hw;

	/*
	 * SM8150 keeps the firmware codec power-plane control disabled (it
	 * uses the software-controlled GDSC path), matching iris_core_init().
	 */
	if (!core->iris_platform_data->legacy_vpu5) {
		ret = ops->sys_interframe_powercollapse(core);
		if (ret)
			goto err_suspend_hw;
	}

	core->vpu_suspended = false;

	return 0;

err_suspend_hw:
	iris_set_hw_state(core, false);
err_power_off:
	iris_vpu_power_off(core);
error:
	dev_err(core->dev, "failed to resume\n");

	return -EBUSY;
}
