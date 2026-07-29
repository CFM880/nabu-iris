# Boot artifact origin

`6.14.11-nabu-iris1-v44-hwctrl-trigger-current.efi` is an exact copy of the
UKI selected by rEFInd's `PreviousBoot` record on the validated tablet's
`ESPNABU` partition (`/dev/sda31`) on 2026-07-29.

- UKI SHA-256: `591e388018e911375391c6ce5ba19b6276d91d8d7088e54468b67f4d398d2926`
- Embedded `.linux` SHA-256: `19bf579aa26ebb328b4893ce35f638b01e235318b7b73684f177f37de2fb5ce9`
- Embedded `.dtb` SHA-256: `b7c9b33898345633c337f74e51ab3c137a990c8dab5ce1d8ab9d71bb91cabaff`
- Embedded release: `6.14.11-nabu-iris1+`
- Build: `#2 SMP PREEMPT Fri Jul 24 16:40:24 +08 2026`
- Command line: `root=PARTLABEL=linux rw fw_devlink=permissive modprobe.blacklist=venus_core,qcom_iris`

The separately supplied module tree contains 762 modules built for this exact
kernel release. Its Iris module is the v140 artifact; Iris is not built into
the UKI.

