## Running eBPF programs with Zig

First step: compile eBPF objects via `zig build`.
This requires using the `freestanding` OS tag and curate the endianness of target machine.

The produced object file can be loaded via `bpftool` to test it.
This is how I found out the "license" section was misplaced.

```
☁  zig-ebpf-probes  sudo bpftool prog load zig-out/bin/probes.o zig/probes/print
[sudo] password for francesco: 
libbpf: prog 'print_number': BPF program load failed: Invalid argument
libbpf: prog 'print_number': -- BEGIN PROG LOAD LOG --
0: R1=ctx(off=0,imm=0) R10=fp0
0: (18) r1 = 0xffff8881b7c08510       ; R1_w=map_value(off=0,ks=4,vs=53,imm=0)
2: (b7) r2 = 42                       ; R2_w=42
3: (85) call bpf_trace_printk#6
cannot call GPL-restricted function from non-GPL compatible program
processed 3 insns (limit 1000000) max_states_per_insn 0 total_states 0 peak_states 0 mark_read 0
-- END PROG LOAD LOG --
libbpf: prog 'print_number': failed to load: -22
libbpf: failed to load object 'zig-out/bin/probes.o'
Error: failed to load object file
```

Using `linksection` we can manipulate the ELF linker sections.
We want to use `@cImport`to interop with the Linux kernel C libraries defining BPF helpers, so we can then call into them inside our eBPF programs.
The Zig std library also has some BPF helpers, but they are not as complete as libbpf.

Second step: using `@embed` to load the object file inside the final binary at compile time.
This allows to ship the same code in a single binary.

Third step: create a perf event to attach the eBPF program to.