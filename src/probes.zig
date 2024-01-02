const std = @import("std");
const BPF = std.os.linux.BPF;
const helpers = BPF.kern.helpers;

export const _license linksection("license") = "GPL".*;

export fn print_pid(_: ?*anyopaque) linksection("perf_event") c_int {
    const text = "Hello from C on pid {d}!\n";
    const printed = helpers.trace_printk(text, text.len, helpers.get_current_pid_tgid(), 0, 0);
    if (printed < 0) {
        return 1;
    }
    return 0;
}
