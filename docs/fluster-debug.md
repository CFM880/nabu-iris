# Fluster V4L2 investigation — 2026-09-08

Final candidate 9, temporarily loaded on 6.14.11-nabu-audio1, passes four of five
original Fluster smoke vectors with the local Iris FFmpeg and matching libraries.

| Vector | Frames | MD5 / result |
|---|---:|---|
| H.264 AUD_MW_E | 100 | e96fe5054de0329a8868d06003375cdb |
| HEVC AMP_A_Samsung_7 | 17 | 93a5875d58072db5539c04e1e943ed9d |
| HEVC Main10 DBLK_A_MAIN10_VIXS_4 | 8 | c4594956bb9e8303f1662f9eb1bcdf50 |
| VP9 quantizer-00 | 2 | e3b792ed5ed3a7c53d17db06bd437ad9 |
| VP9 Profile 2 160x90 | 0 | firmware UNSUPPORTED_STREAM |

## Driver changes

- Keep firmware minimum count unknown until sequence discovery. Allocate the
  initial legacy internal DPB pool consistently with its firmware count promise.
- Treat linear CAPTURE and internal DPB pools as independent allocations.
- Avoid replaying all input properties on legacy CAPTURE start.
- If early CAPTURE already fits the initial sequence, continue without a fake
  DRC flush/LAST. Requeue buffers when resuming a drained/changed session.
- Negotiate P010 on 10-bit sequence discovery; require CAPTURE reallocation
  before START when its pixel format changed.
- Use the SM8150 Iris1 96-pixel minimum and clamp initial format hints.
  Firmware still validates the actual stream dimensions.

H.264 passed ten consecutive untraced runs on candidate 5 and subsequent
four-vector regressions on candidate 7. Candidate 8 adds ERROR-origin diagnostics.
System FFmpeg's initial NV12 request still prevents reliable Main10 negotiation;
use the existing local FFmpeg Iris build with its matching LD_LIBRARY_PATH.

## Remaining vector: dimension limitation

Symbolizing the ERROR caller identifies session_etb_done's
HFI_ERR_SESSION_UNSUPPORTED_STREAM branch. The actual Fluster vector is 160x90.
Re-encoding the same content at 8 and 10 bits gives identical failure at 160x90;
160x96 and 256x128 both pass software MD5 comparisons at both bit depths.
This supports a minimum visible-height limitation. Do not remove or mark the
original vector passed, and do not describe this as lack of VP9 10-bit support.

The final cleanup build adds an explicit unsupported-stream error, keeps
resolution checks on visible dimensions, and scopes H.264 configuration to
legacy platforms. The user confirmed loading it; the final 15-case Fluster
regression gives software 5/5 and V4L2/VA-API 4/5 each. Both 10-bit dimension
probes were repeated on both hardware paths and match software MD5s.
The installed on-disk module is unchanged; scripts/load-module.sh loads a
candidate with dependencies and restores the installed module if loading fails.

VA-API work began after this driver diagnosis. Its H.264/HEVC single-thread
failures were premature EOS during surface sync, losing subsequent references.
After fixing sync, VA-API also passes four original vectors; the 160x90 vector
remains failed. Durable results are in the adjacent iris-vaapi repository at
benchmark-results/fluster-driver-vaapi.{md,json} and its metadata JSON.

Supplementary VP9 10-bit probes at 160x96 and 256x128 now also match software
through VA-API after fixing sync to release held frames with an internal
show-existing AU instead of EOS. These probes are separate from Fluster.

## Latest recovery and userspace follow-up

The sufficient-sequence property experiment was reverted after triggering
a host global recovery. Unknown-session events were unconditionally treated
as core failures; the response handler now restricts recovery to explicit
HFI_EVENT_SYS_ERROR and logs other unknown-session events. User reloaded this
build and the original smoke returned to software 5/5, V4L2/VA-API 4/5.
No deliberate unknown-event fault injection was performed.

The VA-API VP9 resize path now retains retired engines only through explicit
reference surface ownership, then copies the smaller visible rectangle with
correct source/destination strides. Its native-dimension output matches the
original 30-frame reference MD5 three times. Direct V4L2 dynamic visible-size
propagation still needs a fix; the experimental firmware property is disabled.
