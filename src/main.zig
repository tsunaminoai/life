// adapted from https://www.youtube.com/watch?v=0Kx4Y9TVMGg
const std = @import("std");
const rl = @import("raylib");
const rlm = @import("raylib-math");

var random: std.rand.DefaultPrng = undefined;

const screenWidth = 800;
const screenHeight = 450;
const particleRadius = 3.0;

const ParticleList = std.ArrayList(Particle);

const Particle = struct {
    position: rl.Vector2,
    velocity: rl.Vector2,
    color: rl.Color,

    pub fn init(x: f32, y: f32, vx: f32, vy: f32, color: rl.Color) Particle {
        return Particle{
            .position = rl.Vector2.init(x, y),
            .velocity = rl.Vector2.init(vx, vy),
            .color = color,
        };
    }
};

fn Draw(p: Particle) void {
    rl.drawCircleV(p.position, particleRadius, p.color);
}

fn InitRandom() void {
    const time = std.time.microTimestamp();
    random = std.rand.DefaultPrng.init(@intCast(time));
}

fn getRandomFloat() f32 {
    return random.random().float(f32);
}
fn getRandomPosition(clamp: f32) f32 {
    return clamp * getRandomFloat();
}

fn create(allocator: std.mem.Allocator, number: u16, color: rl.Color) !ParticleList {
    var group = ParticleList.init(allocator);

    for (0..number) |_| {
        try group.append(Particle.init(getRandomPosition(screenWidth), getRandomPosition(screenHeight), getRandomFloat(), getRandomFloat(), color));
    }

    return group;
}

fn rule(p1: *ParticleList, p2: *ParticleList, g: f32) void {
    for (p1.items) |*a| {
        var force = rlm.vector2Zero();

        for (p2.items) |b| {
            const delta: rl.Vector2 = rlm.vector2Subtract(a.position, b.position);
            var d = @sqrt(delta.x * delta.x + delta.y * delta.y);
            // std.debug.print("Distance: {}\n", .{d});
            if (d > 0 and d < 50) {
                var F: f32 = g * 1.0 / d;
                // collision
                if (d < particleRadius) {
                    F *= -1;
                }
                force = rlm.vector2Add(force, rlm.vector2Scale(delta, F));
            }
        }
        // std.debug.print("Applied force: {}\n", .{force});
        a.velocity = rlm.vector2Scale(rlm.vector2Add(a.velocity, force), 0.5);
        a.position = rlm.vector2Add(a.position, a.velocity);
        if ((a.position.x <= 0) or (a.position.x >= screenWidth)) {
            a.velocity.x *= -1;
        }
        if ((a.position.y <= 0) or (a.position.y >= screenHeight)) {
            a.velocity.y *= -1;
        }
    }
}

fn Update(args: anytype) void {
    const fields = @typeInfo(@TypeOf(args)).Struct.fields;

    inline for (fields) |field| {
        if (field.type == ParticleList) {
            // std.debug.print("Updating: {any}\n", .{field.name});
            var particles = @field(args, field.name);
            for (particles.items) |p| {
                Draw(p);
            }
        }
    }
}

pub fn main() anyerror!void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const allocator = arena.allocator();

    // Initialization
    //--------------------------------------------------------------------------------------
    InitRandom();

    var b = try create(allocator, 300, rl.Color.blue);
    defer b.deinit();
    var g = try create(allocator, 300, rl.Color.green);
    defer g.deinit();
    var r = try create(allocator, 300, rl.Color.red);
    defer r.deinit();
    var y = try create(allocator, 300, rl.Color.yellow);
    defer y.deinit();

    rl.initWindow(screenWidth, screenHeight, "raylib-zig [core] example - basic window");
    defer rl.closeWindow(); // Close window and OpenGL context

    rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        // Update
        //----------------------------------------------------------------------------------
        rule(&b, &b, getRandomFloat());
        rule(&b, &g, -getRandomFloat());
        rule(&b, &r, getRandomFloat());
        rule(&b, &y, -getRandomFloat());

        rule(&r, &b, getRandomFloat());
        rule(&r, &r, -getRandomFloat());
        rule(&r, &y, getRandomFloat());
        rule(&r, &g, -getRandomFloat());

        rule(&y, &y, -getRandomFloat());
        rule(&y, &g, getRandomFloat());
        rule(&y, &r, -getRandomFloat());
        rule(&y, &b, -getRandomFloat());

        rule(&g, &y, -getRandomFloat());
        rule(&g, &g, getRandomFloat());
        rule(&g, &r, -getRandomFloat());
        rule(&g, &b, -getRandomFloat());
        //----------------------------------------------------------------------------------

        // Draw
        //----------------------------------------------------------------------------------
        rl.beginDrawing();
        defer rl.endDrawing();

        rl.clearBackground(rl.Color.black);

        Update(.{ b, g, r, y });
        rl.drawFPS(10, 10);

        //----------------------------------------------------------------------------------
    }
}
