const std = @import("std");
const time = std.time;

pub const Datetime = struct {
    year: u16,
    month: u4,
    day: u5,
    hours: u5,
    minutes: u6,
    seconds: u6,

    pub fn toString(self: Datetime) []const u8 {
        const fmt = "{d}-{d:0>2}-{d:0>2} {d:0>2}:{d:0>2}:{d:0>2}";
        const args = .{ self.year, self.month, self.day, self.hours, self.minutes, self.seconds };
        var buf: [19]u8 = undefined;
        return std.fmt.bufPrint(&buf, fmt, args) catch unreachable;
    }
};

fn getDatetime(timestamp: u64) Datetime {
    const epoch: time.epoch.EpochSeconds = time.epoch.EpochSeconds{ .secs = timestamp };

    const epochDay = epoch.getEpochDay();
    const yearAndDay = epochDay.calculateYearDay();
    const monthDay = yearAndDay.calculateMonthDay();
    const daySeconds = epoch.getDaySeconds();

    const year = yearAndDay.year;
    const month = monthDay.month.numeric();
    const day = monthDay.day_index + 1;
    const hours = daySeconds.getHoursIntoDay();
    const minutes = daySeconds.getMinutesIntoHour();
    const seconds = daySeconds.getSecondsIntoMinute();

    return Datetime{ .year = year, .month = month, .day = day, .hours = hours, .minutes = minutes, .seconds = seconds };
}

pub fn now() Datetime {
    const timestamp: u64 = @intCast(time.timestamp());
    return getDatetime(timestamp);
}

test "getDatetime" {
    const t1: u64 = 0;
    const dt1: Datetime = comptime getDatetime(t1);

    try std.testing.expectEqual(1970, dt1.year);
    try std.testing.expectEqual(1, dt1.month);
    try std.testing.expectEqual(1, dt1.day);
    try std.testing.expectEqual(0, dt1.hours);
    try std.testing.expectEqual(0, dt1.minutes);
    try std.testing.expectEqual(0, dt1.seconds);
    const dtStr1 = dt1.toString();
    try std.testing.expect(std.mem.eql(u8, "1970-01-01 00:00:00", dtStr1));

    const t2: u64 = 1698840616;
    const dt2: Datetime = comptime getDatetime(t2);
    try std.testing.expectEqual(2023, dt2.year);
    try std.testing.expectEqual(11, dt2.month);
    try std.testing.expectEqual(1, dt2.day);
    try std.testing.expectEqual(12, dt2.hours);
    try std.testing.expectEqual(10, dt2.minutes);
    try std.testing.expectEqual(16, dt2.seconds);
    const dtStr2 = dt2.toString();
    try std.testing.expect(std.mem.eql(u8, "2023-11-01 12:10:16", dtStr2));
}
