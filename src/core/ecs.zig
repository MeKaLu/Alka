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

pub const Error = error{ InvalidComponent, InvalidEntity, InvalidEntityID, InvalidEntityName, InvalidGroup } || utils.Error;

/// Stores the component struct in a convenient way
pub fn StoreComponent(comptime name: []const u8, comptime Component: type) type {
    return struct {
        const Self = @This();
        pub const T = Component;
        pub const Name = name;

        alloc: *std.mem.Allocator = undefined,
        components: UniqueList(T) = undefined,

        /// Initializes the storage component
        pub fn init(alloc: *std.mem.Allocator) Error!Self {
            return Self{
                .alloc = alloc,
                .components = try UniqueList(T).init(alloc, 5),
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
            return !self.components.isUnique(id);
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

/// World, manages the entities and groups 
pub fn World(comptime Storage: type) type {
    return struct {
        const component_names = comptime std.meta.fieldNames(T);
        const Self = @This();
        /// Storage component types
        pub const T = Storage;

        /// Group of the StorageComponents
        pub const Group = struct {

            /// Iterator
            pub fn Iterator(comptime len: usize, compmask: [len][]const u8) type {
                return struct {
                    group: Group = undefined,
                    index: usize = 0,
                    mask: [len][]const u8 = compmask,

                    pub const Entry = struct {
                        value: ?u64 = 0,
                        index: usize = 0,
                    };

                    fn getID(it: @This()) ?u64 {
                        if (it.group.world.entity.registers.items[it.index].data != null) {
                            const id = it.group.world.entity.registers.items[it.index].id;

                            for (it.mask) |cname| {
                                inline for (component_names) |name| {
                                    const typ = @TypeOf(@field(it.group.registers, name));
                                    if (std.mem.eql(u8, typ.Name, cname)) {
                                        if (!@field(it.group.registers, name).has(id)) {
                                            return null;
                                        }
                                    }
                                }
                            }

                            return id;
                        }
                        return null;
                    }

                    pub fn next(it: *@This()) ?Entry {
                        if (it.index >= it.group.world.entity.registers.items.len) return null;

                        const result = Entry{ .value = it.getID(), .index = it.index };
                        it.index += 1;

                        return result;
                    }

                    /// Reset the iterator
                    pub fn reset(it: *@This()) void {
                        it.index = 0;
                    }
                };
            }

            alloc: *std.mem.Allocator = undefined,
            world: *const Self = undefined,
            registers: T = undefined,

            /// Creates the group
            pub fn create(self: *const Self) Error!Group {
                var result = Group{
                    .alloc = self.alloc,
                    .world = self,
                };

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(result.registers, name));
                    @field(result.registers, name) = try typ.init(result.alloc);
                }
                return result;
            }

            /// Collects the entities
            /// Returns the entity id's
            pub fn view(self: *const Group, comptime len: usize, compnames: [len][]const u8) Error!UniqueList(u64) {
                var alloc = self.alloc;
                const world = self.world;

                var list = try UniqueList(u64).init(alloc, 0);
                var it = world.entity.registers.iterator();
                while (it.next()) |entry| {
                    if (entry.data != null) {
                        const id = entry.id;
                        var hasAll = true;

                        for (compnames) |cname| {
                            inline for (component_names) |name| {
                                const typ = @TypeOf(@field(self.registers, name));
                                if (std.mem.eql(u8, typ.Name, cname)) {
                                    if (!@field(self.registers, name).has(id)) {
                                        hasAll = false;
                                        break;
                                    }
                                }
                            }
                        }

                        if (hasAll) {
                            //std.log.info("loading: {}", .{iterator.index});
                            try list.append(it.index, id);
                        }
                    }
                }
                return list;
            }

            /// Collects the entities
            /// Returns the entity id's
            pub fn viewFixed(self: *const Group, comptime max_ent: usize, comptime len: usize, compnames: [len][]const u8) Error![max_ent]?u64 {
                var alloc = self.alloc;
                const world = self.world;

                var list: [max_ent]?u64 = undefined;
                var it = world.entity.registers.iterator();
                while (it.next()) |entry| {
                    if (it.index >= max_ent) break;

                    if (entry.data != null) {
                        const id = entry.id;
                        var hasAll = true;

                        for (compnames) |cname| {
                            inline for (component_names) |name| {
                                const typ = @TypeOf(@field(self.registers, name));
                                if (std.mem.eql(u8, typ.Name, cname)) {
                                    if (!@field(self.registers, name).has(id)) {
                                        hasAll = false;
                                        break;
                                    }
                                }
                            }
                        }

                        if (hasAll) {
                            //std.log.info("loading: {}", .{iterator.index});
                            list[it.index] = id;
                        }
                    }
                }
                return list;
            }

            /// Returns the iterator
            pub fn iterator(comptime len: usize, compnames: [len][]const u8) type {
                return Iterator(
                    len,
                    compnames,
                );
            }

            /// Adds a component
            pub fn add(self: *Group, entity_id: u64, comptime storage_component_type: type, component: storage_component_type.T) Error!void {
                if (!self.world.entity.hasID(entity_id)) return Error.InvalidEntityID;

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
            pub fn get(self: Group, entity_id: u64, comptime storage_component_type: type) Error!storage_component_type.T {
                if (!self.world.entity.hasID(entity_id)) return Error.InvalidEntityID;

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
            pub fn getPtr(self: *Group, entity_id: u64, comptime storage_component_type: type) Error!*storage_component_type.T {
                if (!self.world.entity.hasID(entity_id)) return Error.InvalidEntityID;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(self.registers, name));
                    if (typ == storage_component_type) {
                        return @field(self.registers, name).getPtr(entity_id);
                    }
                }
                return Error.InvalidComponent;
            }

            /// Is the component exists in side of the given entity?
            pub fn has(self: Group, entity_id: u64, comptime storage_component_type: type) Error!bool {
                if (!self.world.entity.hasID(entity_id)) return Error.InvalidEntityID;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(self.registers, name));
                    if (typ == storage_component_type) {
                        return @field(self.registers, name).has(entity_id);
                    }
                }
                return false;
            }

            /// Removes a component
            pub fn remove(self: *Group, entity_id: u64, comptime storage_component_type: type) Error!void {
                if (!self.world.entity.hasID(entity_id)) return Error.InvalidEntityID;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(self.registers, name));
                    if (typ == storage_component_type) {
                        return @field(self.registers, name).remove(entity_id);
                    }
                }
                return Error.InvalidComponent;
            }

            /// Destroys the group
            pub fn destroy(self: Group) void {
                inline for (component_names) |name| {
                    @field(self.registers, name).deinit();
                }
            }
        };

        pub const Entity = struct {
            alloc: *std.mem.Allocator = undefined,
            registers: UniqueList([]const u8) = undefined,

            /// Creates an entity with unique name and
            /// returns the unique id of the entity
            pub fn create(self: *Entity, name: []const u8) Error!u64 {
                if (self.has(name)) return Error.InvalidEntityName;

                const id = self.registers.findUnique();
                try self.registers.append(id, name);
                return id;
            }

            /// Creates an entity with unique id
            pub fn createID(self: *Entity, id: u64) Error!void {
                if (self.hasID(id)) return Error.InvalidEntityID;

                var name = std.fmt.allocPrint(self.alloc, "alka_private{}", .{id}) catch @panic("Allocation failed!");
                defer self.alloc.free(name);
                try self.registers.append(id, name);
            }

            /// Destroys an entity with given name
            pub fn destroy(self: *Entity, name: []const u8) Error!void {
                const i = try self.hasNameID(name);

                return self.registers.remove(i);
            }

            /// Destroys an entity with given ID
            pub fn destroyID(self: *Entity, id: u64) Error!void {
                const i = if (self.hasID(id)) id else Error.InvalidEntityID;

                return self.registers.remove(i);
            }

            /// Is the entity with given name exists? 
            pub fn has(self: Entity, name: []const u8) bool {
                var it = self.registers.iterator();
                while (it.next()) |entry| {
                    if (entry.data) |data| {
                        if (std.mem.eql(u8, data, name)) return true;
                    }
                }

                return false;
            }

            /// Is the entity with given name exists?
            /// Returns the id of it, if it does not exists, returns Error.InvalidEntity 
            pub fn hasNameID(self: Entity, name: []const u8) Error!u64 {
                var it = self.registers.iterator();
                while (it.next()) |entry| {
                    if (entry.data) |data| {
                        if (std.mem.eql(u8, data, name)) return entry.id;
                    }
                }

                return Error.InvalidEntity;
            }

            /// Is the entity with given id exists?
            pub fn hasID(self: Entity, id: u64) bool {
                var it = self.registers.iterator();
                while (it.next()) |entry| {
                    if (entry.id == id) return true;
                }

                return false;
            }
        };

        alloc: *std.mem.Allocator = undefined,
        entity: Entity = undefined,
        group: ?*Group = null,

        /// Initializes the world
        pub fn init(alloc: *std.mem.Allocator) Error!Self {
            return Self{
                .alloc = alloc,
                .entity = Entity{
                    .alloc = alloc,
                    .registers = try UniqueList([]const u8).init(alloc, 5),
                },
            };
        }

        /// Pushes the group
        pub fn pushGroup(self: *Self, group: *Group) void {
            self.group = group;
        }

        /// Pops the group 
        pub fn popGroup(self: *Self) void {
            self.group = null;
        }

        /// Collects the entities
        /// Returns the entity id's
        pub fn view(self: *const Self, comptime len: usize, compnames: [len][]const u8) Error!UniqueList(u64) {
            if (self.group) |group|
                return group.view(len, compnames);
            return Error.InvalidGroup;
        }

        /// Collects the entities
        /// Returns the entity id's
        pub fn viewFixed(self: *const Self, comptime max_ent: usize, comptime len: usize, compnames: [len][]const u8) Error![max_ent]?u64 {
            if (self.group) |group|
                return group.viewFixed(max_ent, len, compnames);
            return Error.InvalidGroup;
        }

        /// Adds a component to the entity
        pub fn addComponent(self: *Self, entity_name: []const u8, component_name: []const u8, component: anytype) Error!void {
            if (self.group) |group| {
                const id = try self.entity.hasNameID(entity_name);

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(group.registers, name));
                    if (std.mem.eql(u8, component_name, typ.Name)) {
                        if (typ.T == @TypeOf(component))
                            return @field(group.registers, name).add(id, component);
                    }
                }
                return Error.InvalidComponent;
            }
            return Error.InvalidGroup;
        }

        /// Adds a component to the entity
        pub fn addComponentID(self: *Self, entity_id: u64, component_name: []const u8, component: anytype) Error!void {
            if (self.group) |group| {
                if (!self.entity.hasID(entity_id)) return Error.InvalidEntityID;
                const id = entity_id;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(group.registers, name));
                    if (std.mem.eql(u8, component_name, typ.Name)) {
                        if (typ.T == @TypeOf(component))
                            return @field(group.registers, name).add(id, component);
                    }
                }
                return Error.InvalidComponent;
            }
            return Error.InvalidGroup;
        }

        /// Returns the desired component
        /// NOTE: READ ONLY
        pub fn getComponent(self: *Self, entity_name: []const u8, component_name: []const u8, comptime component_type: type) Error!component_type {
            if (self.group) |group| {
                const id = try self.entity.hasNameID(entity_name);

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(group.registers, name));
                    if (std.mem.eql(u8, component_name, typ.Name)) {
                        if (typ.T == component_type)
                            return @field(group.registers, name).get(id);
                    }
                }
                return Error.InvalidComponent;
            }
            return Error.InvalidGroup;
        }

        /// Returns the desired component
        /// NOTE: READ ONLY
        pub fn getComponentID(self: *Self, entity_id: u64, component_name: []const u8, comptime component_type: type) Error!component_type {
            if (self.group) |group| {
                if (!self.entity.hasID(entity_id)) return Error.InvalidEntityID;
                const id = entity_id;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(group.registers, name));
                    if (std.mem.eql(u8, component_name, typ.Name)) {
                        if (typ.T == component_type)
                            return @field(group.registers, name).get(id);
                    }
                }
                return Error.InvalidComponent;
            }
            return Error.InvalidGroup;
        }

        /// Returns the desired component
        /// NOTE: MUTABLE 
        pub fn getComponentPtr(self: *Self, entity_name: []const u8, component_name: []const u8, comptime component_type: type) Error!*component_type {
            if (self.group) |group| {
                const id = try self.entity.hasNameID(entity_name);

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(group.registers, name));
                    if (std.mem.eql(u8, component_name, typ.Name)) {
                        if (typ.T == component_type)
                            return @field(group.registers, name).getPtr(id);
                    }
                }
                return Error.InvalidComponent;
            }
            return Error.InvalidGroup;
        }

        /// Returns the desired component
        /// NOTE: MUTABLE 
        pub fn getComponentPtrID(self: *Self, entity_id: u64, component_name: []const u8, comptime component_type: type) Error!*component_type {
            if (self.group) |group| {
                if (!self.entity.hasID(entity_id)) return Error.InvalidEntityID;
                const id = entity_id;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(group.registers, name));
                    if (std.mem.eql(u8, component_name, typ.Name)) {
                        if (typ.T == component_type)
                            return @field(group.registers, name).getPtr(id);
                    }
                }
                return Error.InvalidComponent;
            }
            return Error.InvalidGroup;
        }

        /// Removes a component to the entity
        pub fn removeComponent(self: *Self, entity_name: []const u8, component_name: []const u8) Error!void {
            if (self.group) |group| {
                const id = try self.entity.hasNameID(entity_name);

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(group.registers, name));
                    if (std.mem.eql(u8, component_name, typ.Name)) {
                        return @field(group.registers, name).remove(id);
                    }
                }
                return Error.InvalidComponent;
            }
            return Error.InvalidGroup;
        }

        /// Removes a component to the entity
        pub fn removeComponentID(self: *Self, entity_id: u64, component_name: []const u8) Error!void {
            if (self.group) |group| {
                if (!self.entity.hasID(entity_id)) return Error.InvalidEntityID;
                const id = entity_id;

                inline for (component_names) |name| {
                    const typ = @TypeOf(@field(group.registers, name));
                    if (std.mem.eql(u8, component_name, typ.Name)) {
                        return @field(group.registers, name).remove(id);
                    }
                }
                return Error.InvalidComponent;
            }
            return Error.InvalidGroup;
        }

        /// Deinitializes the world
        pub fn deinit(self: Self) void {
            self.entity.registers.deinit();
        }
    };
}
