// -----------------------------------------
// |           Alka 1.0.0                  |
// -----------------------------------------
//
//Copyright © 2020-2021 Mehmet Kaan Uluç <kaanuluc@protonmail.com>
//
//This software is provided 'as-is', without any express or implied
//warranty. In no event will the authors be held liable for any damages
//arising from the use of this software.
//
//Permission is granted to anyone to use this software for any purpose,
//including commercial applications, and to alter it and redistribute it
//freely, subject to the following restrictions:
//
//1. The origin of this software must not be misrepresented; you must not
//   claim that you wrote the original software. If you use this software
//   in a product, an acknowledgment in the product documentation would
//   be appreciated but is not required.
//
//2. Altered source versions must be plainly marked as such, and must not
//   be misrepresented as being the original software.
//
//3. This notice may not be removed or altered from any source
//   distribution.

const std = @import("std");
const utils = @import("utils.zig");
const UniqueList = utils.UniqueList;

pub const Error = error{ InvalidComponent, InvalidEntity, InvalidEntityID, InvalidEntityName } || utils.Error;

/// Stores the component struct in a convenient way
pub fn StoreComponent(comptime name: []const u8, comptime Component: type) type {
    comptime const is_empty = @sizeOf(Component) == 0;
    comptime const ComponentOrDummy = if (is_empty) struct { dummy: u1 } else Component;

    return struct {
        const Self = @This();
        pub const T = ComponentOrDummy;
        pub const Name = name;

        alloc: *std.mem.Allocator = undefined,
        components: UniqueList(T) = undefined,

        /// Initializes the storage component
        pub fn init(alloc: *std.mem.Allocator) Error!Self {
            return Self{
                .alloc = alloc,
                .components = try UniqueList(T).init(alloc, 0),
            };
        }

        /// Adds a component
        pub fn add(self: *Self, id: u64, data: T) Error!void {
            return self.components.append(id, data);
        }

        /// Returns a component
        /// NOTE: READ ONLY
        pub fn get(self: Self, id: u64) Error!T {
            return self.components.get(id);
        }

        /// Returns a component
        /// NOTE: MUTABLE
        pub fn getPtr(self: Self, id: u64) Error!*T {
            return self.components.getPtr(id);
        }

        /// Has the component? 
        pub fn has(self: Self, id: u64) bool {
            return self.components.isUnique(id);
        }

        /// Removes the component 
        pub fn remove(self: *Self, id: u64) Error!void {
            return self.components.remove(id);
        }

        /// Deinitializes the storage component
        pub fn deinit(self: Self) void {
            self.components.deinit();
        }
    };
}

/// World, manages the entities 
pub fn World(comptime Storage: type) type {
    return struct {
        const Self = @This();
        /// Storage component types
        pub const T = Storage;

        alloc: *std.mem.Allocator = undefined,
        entities: UniqueList([]const u8) = undefined,

        /// Collects the entities, with required components
        pub fn View(comptime components: type) type {
            return struct {
                const component_names = comptime std.meta.fieldNames(components);
                const _View = @This();

                /// Collects the entities
                /// Returns the entity id's
                pub fn collect(alloc: *std.mem.Allocator, group: *const Group) Error!UniqueList(u64) {
                    const ghost = group.registers;
                    const world = group.world;

                    var list = try UniqueList(u64).init(alloc, 1);
                    var iterator = world.entities.iterator();
                    while (iterator.next()) |entry| {
                        if (entry.data != null) {
                            const id = entry.id;
                            var hasAll = true;

                            inline for (component_names) |name| {
                                const typ = @TypeOf(@field(ghost, name));
                                if (!try group.has(id, typ)) {
                                    hasAll = false;
                                    break;
                                }
                            }

                            if (hasAll) {
                                //std.log.info("loading: {}", .{id});
                                try list.append(list.findUnique(), id);
                            }
                        }
                    }
                    return list;
                }
            };
        }

        /// Group of the StorageComponents
        pub const Group = struct {
            const component_names = comptime std.meta.fieldNames(T);
            const _Group = @This();

            alloc: *std.mem.Allocator = undefined,
            world: *const Self = undefined,
            registers: T = undefined,

            /// Initializes the group
            pub fn init(alloc: *std.mem.Allocator, world: *const Self) Error!_Group {
                var self = _Group{
                    .alloc = alloc,
                    .world = world,
                };

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(self.registers, name));
                    @field(self.registers, name) = try typ.init(self.alloc);
                }

                return self;
            }

            /// Adds a component
            pub fn add(self: *_Group, entity_id: u64, comptime storage_component_type: type, component: storage_component_type.T) Error!void {
                if (!self.world.hasEntityID(entity_id)) return Error.InvalidEntityID;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(self.registers, name));
                    if (typ == storage_component_type) {
                        return @field(self.registers, name).add(entity_id, component);
                    }
                }
                return Error.InvalidComponent;
            }

            /// Returns the desired component
            /// NOTE: READ ONLY
            pub fn get(self: _Group, entity_id: u64, comptime storage_component_type: type) Error!storage_component_type.T {
                if (!self.world.hasEntityID(entity_id)) return Error.InvalidEntityID;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(self.registers, name));
                    if (typ == storage_component_type) {
                        return @field(self.registers, name).get(entity_id);
                    }
                }
                return Error.InvalidComponent;
            }

            /// Returns the desired component
            /// NOTE: MUTABLE 
            pub fn getPtr(self: *_Group, entity_id: u64, comptime storage_component_type: type) Error!*storage_component_type.T {
                if (!self.world.hasEntityID(entity_id)) return Error.InvalidEntityID;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(self.registers, name));
                    if (typ == storage_component_type) {
                        return @field(self.registers, name).getPtr(entity_id);
                    }
                }
                return Error.InvalidComponent;
            }

            /// Is the component exists in side of the given entity?
            pub fn has(self: _Group, entity_id: u64, comptime storage_component_type: type) Error!bool {
                if (!self.world.hasEntityID(entity_id)) return Error.InvalidEntityID;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(self.registers, name));
                    if (typ == storage_component_type) {
                        return @field(self.registers, name).has(entity_id);
                    }
                }
                return false;
            }

            /// Removes a component
            pub fn remove(self: *_Group, entity_id: u64, comptime storage_component_type: type) Error!void {
                if (!self.world.hasEntityID(entity_id)) return Error.InvalidEntityID;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(self.registers, name));
                    if (typ == storage_component_type) {
                        return @field(self.registers, name).remove(entity_id);
                    }
                }
                return Error.InvalidComponent;
            }

            /// Deinitializes the group
            pub fn deinit(self: _Group) void {
                inline for (component_names) |name| {
                    @field(self.registers, name).deinit();
                }
            }
        };

        /// Initializes the world
        pub fn init(alloc: *std.mem.Allocator) Error!Self {
            return Self{
                .alloc = alloc,
                .entities = try UniqueList([]const u8).init(alloc, 1),
            };
        }

        /// Creates an entity with unique name and
        /// returns the unique id of the entity
        pub fn createEntity(self: *Self, name: []const u8) Error!u64 {
            if (self.hasEntity(name)) return Error.InvalidEntityName;

            const id = self.entities.findUnique();
            try self.entities.append(id, name);
            return id;
        }

        /// Destroys an entity with given name
        pub fn destroyEntity(self: *Self, name: []const u8) Error!void {
            const i = try self.hasEntityNameID(name);

            return self.entities.remove(i);
        }

        /// Destroys an entity with given ID
        pub fn destroyEntityID(self: *Self, id: u64) Error!void {
            const i = if (self.hasEntityID(id)) id else Error.InvalidEntityID;

            return self.entities.remove(i);
        }

        /// Is the entity with given name exists? 
        pub fn hasEntity(self: Self, name: []const u8) bool {
            var it = self.entities.iterator();
            while (it.next()) |entry| {
                if (entry.data) |data| {
                    if (std.mem.eql(u8, data, name)) return true;
                }
            }

            return false;
        }

        /// Is the entity with given name exists?
        /// Returns the id of it, if it does not exists, returns Error.InvalidEntity 
        pub fn hasEntityNameID(self: Self, name: []const u8) Error!u64 {
            var it = self.entities.iterator();
            while (it.next()) |entry| {
                if (entry.data) |data| {
                    if (std.mem.eql(u8, data, name)) return entry.id;
                }
            }

            return Error.InvalidEntity;
        }

        /// Is the entity with given id exists?
        pub fn hasEntityID(self: Self, id: u64) bool {
            var it = self.entities.iterator();
            while (it.next()) |entry| {
                if (entry.id == id) return true;
            }

            return false;
        }

        /// Deinitializes the world
        pub fn deinit(self: Self) void {
            self.entities.deinit();
        }
    };
}
