# PLZ110 source-built BTF compatibility asset

`plz110-16.0.10.500-source-baseline.btf.zst` contains the raw `.BTF` payload
from the clean `baseline` r22 build (GitHub Actions run `33279099375`). That
build used official OnePlus Common commit
`844001fb8721c3ee305f17a51628744997f787a0`, the pinned PLZ110 configuration,
and Android Clang r536225 build 14043575. It does not come from an OEM firmware
partition.

The uncompressed blob has these locked properties:

- SHA-256: `c7693da6516da0aa0170b78ce838dd17cccd40f9a1cedac6bba47f40ad542658`
- BTF types: `164887`
- type section length: `4186436`
- string section length: `2724181`

`bpftool` successfully loads the shipping PLZ110
`oplus_bsp_sched_ext.ko` split BTF with this blob as its base. The same module
fails against r30's automatically generated 165497-type BTF. The workflow
checks both the compressed asset and raw BTF hashes before use and verifies the
same raw payload again from the final linked `vmlinux`.
