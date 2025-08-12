const std = @import("std");
const testing = std.testing;

const MatrixError = error{
    OnlyForSquareMatrix,
    WrongDimensions,
};

pub fn CreateMatrix(T: type, comptime rows: usize, comptime cols: usize) type {
    return struct {
        const Self = @This();

        const n_rows = rows;
        const n_cols = cols;
        const n_elements = n_rows * n_cols;

        values: []T,

        pub fn init(allocator: std.mem.Allocator) !Self {
            return Self{ .values = try allocator.alloc(T, n_elements) };
        }

        pub fn free(self: Self, allocator: std.mem.Allocator) void {
            allocator.free(self.values);
        }

        pub fn zeros(allocator: std.mem.Allocator) !Self {
            const list = try allocator.alloc(T, n_elements);
            for (list) |*element| {
                element.* = 0.0;
            }

            return Self{ .values = list };
        }

        pub fn identity(allocator: std.mem.Allocator) !Self {
            comptime if (n_rows != n_cols) {
                @compileError("The identity is only possible for square matrices.");
            };
            var matrix = try zeros(allocator);

            for (0..n_rows) |row| {
                matrix.values[row * n_cols + row] = 1.0;
            }

            return matrix;
        }

        pub fn random(allocator: std.mem.Allocator) !Self {
            const list = try allocator.alloc(T, n_elements);
            var rnd = std.Random.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                try std.posix.getrandom(std.mem.asBytes(&seed));
                break :blk seed;
            });
            const rand = rnd.random();

            for (list) |*element| {
                element.* = rand.float(f64);
            }

            return Self{ .values = list };
        }

        pub fn create(allocator: std.mem.Allocator, values: []const T) !Self {
            const list = try allocator.alloc(T, n_elements);

            for (values, list) |value, *element| {
                element.* = value;
            }

            return Self{ .values = list };
        }

        pub fn at(self: *Self, row: usize, col: usize) *T {
            return &self.values[row * n_cols + col];
        }

        pub fn add(allocator: std.mem.Allocator, input_1: Self, input_2: Self) !Self {
            const list = try allocator.alloc(T, n_elements);

            for (list, input_1.values, input_2.values) |*element, a, b| {
                element.* = a + b;
            }

            return Self{ .values = list };
        }

        pub fn sub(allocator: std.mem.Allocator, input_1: Self, input_2: Self) !Self {
            const list = try allocator.alloc(T, n_rows * n_cols);

            for (list, input_1.values, input_2.values) |*element, a, b| {
                element.* = a - b;
            }

            return Self{ .values = list };
        }

        pub fn dot(self: *Self, left: anytype, right: anytype) !void {
            comptime if (@field(@TypeOf(left), "n_cols") != @field(@TypeOf(right), "n_rows")) {
                @compileError("The matrices have different dimensions, they can't be multiplyed.");
            };

            const left_cols = @field(@TypeOf(left), "n_cols");
            const left_rows = @field(@TypeOf(left), "n_rows");
            const right_cols = @field(@TypeOf(right), "n_cols");

            for (0..left_rows) |i| {
                for (0..right_cols) |j| {
                    self.at(i, j).* = 0;

                    for (0..left_cols) |k| {
                        self.at(i, j).* += left.values[i * left_cols + k] * right.values[k * right_cols + j];
                    }
                }
            }
        }
    };
}

const Matrix2x2 = CreateMatrix(f64, 2, 2);
const Matrix3x3 = CreateMatrix(f64, 3, 3);

test "create a identity matrix" {
    var id_2 = try Matrix2x2.identity(testing.allocator);
    defer id_2.free(testing.allocator);

    try testing.expectApproxEqRel(1.0, id_2.values[0], 1e-6);
    try testing.expectApproxEqRel(0.0, id_2.values[1], 1e-6);
    try testing.expectApproxEqRel(0.0, id_2.values[2], 1e-6);
    try testing.expectApproxEqRel(1.0, id_2.values[3], 1e-6);
}

test "creating a matrix with random values" {
    var id_2 = try Matrix2x2.random(testing.allocator);
    defer id_2.free(testing.allocator);

    try testing.expect(0 <= id_2.values[0]);
    try testing.expect(1 >= id_2.values[0]);
    try testing.expect(0 <= id_2.values[1]);
    try testing.expect(1 >= id_2.values[1]);
    try testing.expect(0 <= id_2.values[2]);
    try testing.expect(1 >= id_2.values[2]);
    try testing.expect(0 <= id_2.values[3]);
    try testing.expect(1 >= id_2.values[3]);
}

test "creating a matrix with input values" {
    var id_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer id_2.free(testing.allocator);

    try testing.expectApproxEqRel(0.0, id_2.values[0], 1e-6);
    try testing.expectApproxEqRel(2.0, id_2.values[1], 1e-6);
    try testing.expectApproxEqRel(1.0, id_2.values[2], 1e-6);
    try testing.expectApproxEqRel(6.0, id_2.values[3], 1e-6);
}

test "the at method gets the right values" {
    var id_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer id_2.free(testing.allocator);

    try testing.expectApproxEqRel(0.0, id_2.at(0, 0).*, 1e-6);
    try testing.expectApproxEqRel(2.0, id_2.at(0, 1).*, 1e-6);
    try testing.expectApproxEqRel(1.0, id_2.at(1, 0).*, 1e+6);
    try testing.expectApproxEqRel(6.0, id_2.at(1, 1).*, 1e-6);
}

test "addition of matrices" {
    var input_1 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer input_1.free(testing.allocator);
    var input_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 1.0, -2.0, 3.0, 6.5 });
    defer input_2.free(testing.allocator);

    const actual = try Matrix2x2.add(testing.allocator, input_1, input_2);
    defer actual.free(testing.allocator);

    const expected = try Matrix2x2.create(testing.allocator, &[_]f64{ 1.0, 0.0, 4.0, 12.5 });
    defer expected.free(testing.allocator);

    try testing.expectApproxEqRel(expected.values[0], actual.values[0], 1e-6);
    try testing.expectApproxEqRel(expected.values[1], actual.values[1], 1e-6);
    try testing.expectApproxEqRel(expected.values[2], actual.values[2], 1e-6);
    try testing.expectApproxEqRel(expected.values[3], actual.values[3], 1e-6);
}

test "substraction of matrices" {
    var input_1 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer input_1.free(testing.allocator);
    var input_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 1.0, -2.0, 3.0, 6.5 });
    defer input_2.free(testing.allocator);

    const actual = try Matrix2x2.sub(testing.allocator, input_1, input_2);
    defer actual.free(testing.allocator);

    const expected = try Matrix2x2.create(testing.allocator, &[_]f64{ -1.0, 4.0, -2.0, -0.5 });
    defer expected.free(testing.allocator);

    try testing.expectApproxEqRel(expected.values[0], actual.values[0], 1e-6);
    try testing.expectApproxEqRel(expected.values[1], actual.values[1], 1e-6);
    try testing.expectApproxEqRel(expected.values[2], actual.values[2], 1e-6);
    try testing.expectApproxEqRel(expected.values[3], actual.values[3], 1e-6);
}

test "multiplication of matrices" {
    var input_1 = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 2.0, 1.0, 6.0 });
    defer input_1.free(testing.allocator);
    var input_2 = try Matrix2x2.create(testing.allocator, &[_]f64{ 1.0, -2.0, 3.0, 6.5 });
    defer input_2.free(testing.allocator);

    var actual = try Matrix2x2.init(testing.allocator);
    defer actual.free(testing.allocator);
    try actual.dot(input_1, input_2);

    const expected = try Matrix2x2.create(testing.allocator, &[_]f64{ 6.0, 13.0, 19.0, 37.0 });
    defer expected.free(testing.allocator);

    try testing.expectApproxEqRel(expected.values[0], actual.values[0], 1e-6);
    try testing.expectApproxEqRel(expected.values[1], actual.values[1], 1e-6);
    try testing.expectApproxEqRel(expected.values[2], actual.values[2], 1e-6);
    try testing.expectApproxEqRel(expected.values[3], actual.values[3], 1e-6);
}

test "multiplication of matrices of different dimensions" {
    var input_1 = try CreateMatrix(f64, 2, 1).create(testing.allocator, &[_]f64{
        0.0,
        2.0,
    });
    defer input_1.free(testing.allocator);
    var input_2 = try CreateMatrix(f64, 1, 2).create(testing.allocator, &[_]f64{
        1.0,
        -2.0,
    });
    defer input_2.free(testing.allocator);

    var actual = try Matrix2x2.init(testing.allocator);
    defer actual.free(testing.allocator);
    try actual.dot(input_1, input_2);

    const expected = try Matrix2x2.create(testing.allocator, &[_]f64{ 0.0, 0.0, 2.0, -4.0 });
    defer expected.free(testing.allocator);

    try testing.expectApproxEqRel(expected.values[0], actual.values[0], 1e-6);
    try testing.expectApproxEqRel(expected.values[1], actual.values[1], 1e-6);
    try testing.expectApproxEqRel(expected.values[2], actual.values[2], 1e-6);
    try testing.expectApproxEqRel(expected.values[3], actual.values[3], 1e-6);
}
