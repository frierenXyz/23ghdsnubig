--[[
    WindUI Example 2
]]


local cloneref = (cloneref or clonereference or function(instance) return instance end)
local ReplicatedStorage = cloneref(game:GetService("ReplicatedStorage"))
local RunService = cloneref(game:GetService("RunService"))

local WindUI

do
    local ok, result = pcall(function()
        return require("./src/Init")
    end)
    
    if ok then
        WindUI = result
    else 
        if RunService:IsStudio() or not writefile then
            WindUI = require(ReplicatedStorage:WaitForChild("WindUI"):WaitForChild("Init"))
        else
            WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Footagesus/WindUI/main/dist/main.lua"))()
        end
    end
end

local Players = game:GetService('Players')
local UserInputService = game:GetService('UserInputService')
local TweenService = game:GetService('TweenService')
local Stats = game:GetService('Stats')
local Debris = game:GetService('Debris')
local CoreGui = game:GetService('CoreGui')

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

if not LocalPlayer.Character then
    LocalPlayer.CharacterAdded:Wait()
end

local Alive = workspace:FindFirstChild("Alive") or workspace:WaitForChild("Alive")
local Runtime = workspace.Runtime

-- Initialize getgenv variables
getgenv().AutoParryMode = getgenv().AutoParryMode or "Remote"
getgenv().AutoParryNotify = getgenv().AutoParryNotify or false
getgenv().CooldownProtection = getgenv().CooldownProtection or false
getgenv().AutoAbility = getgenv().AutoAbility or false
getgenv().BallVelocityAbove800 = getgenv().BallVelocityAbove800 or false

local function update_divisor()
    System.__properties.__divisor_multiplier = 0.59 + (System.__properties.__accuracy - 1) * (3 / 99)
end

local System = {
    __properties = {
        __autoparry_enabled = false,
        __triggerbot_enabled = false,
        __manual_spam_enabled = false,
        __auto_spam_enabled = false,
        __play_animation = false,
        __randomized_accuracy_enabled = false,
        __curve_mode = 1,
        __accuracy = 1,
        __divisor_multiplier = 1.1,
        __parried = false,
        __training_parried = false,
        __spam_threshold = 1.5,
        __parries = 0,
        __parry_key = nil,
        __grab_animation = nil,
        __tornado_time = tick(),
        __first_parry_done = false,
        __connections = {},
        __reverted_remotes = {},
        __spam_accumulator = 0,
        __spam_rate = 240,
        __infinity_active = false,
        __deathslash_active = false,
        __timehole_active = false,
        __slashesoffury_active = false,
        __slashesoffury_count = 0,
        __is_mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled,
        __mobile_guis = {},
        __last_parry_time = 0,
        __parry_cooldown = 0.1,
        __min_parry_distance = 8,
        __double_parry_prevention = true,
        __peak_velocity = 0,
        __last_ball_id = nil,
        __ball_velocity_enabled = false,
        __ball_velocity_gui = nil,
        __auto_spam_distance_multiplier = 1.0,
        __spam_target = nil,
        __spam_target_time = 0
    },
    
    __config = {
        __curve_names = {'Camera', 'Random', 'Accelerated', 'Backwards', 'Slow', 'High'},
        __settings = {
            __parry_distance = 50,
            __min_ball_speed = 10,
            __max_ball_speed = 1000000,
            __high_velocity_threshold = 10000,
            __extreme_velocity_threshold = 100000
        },
        __detections = {
            __infinity = false,
            __deathslash = false,
            __timehole = false,
            __slashesoffury = false,
            __phantom = false
        }
    },
    
    __triggerbot = {
        __enabled = false,
        __is_parrying = false,
        __parries = 0,
        __max_parries = 10000,
        __parry_delay = 0.5
    }
}

local revertedRemotes = System.__properties.__reverted_remotes
local originalMetatables = {}
local Parry_Key = nil
local PF = nil
local SC = nil

if ReplicatedStorage:FindFirstChild("Controllers") then
    for _, child in ipairs(ReplicatedStorage.Controllers:GetChildren()) do
        if child.Name:match("^SwordsController%s*$") then
            SC = child
        end
    end
end

local function update_divisor()
    System.__properties.__divisor_multiplier = 0.59 + (System.__properties.__accuracy - 1) * (3 / 99)
end

local function update_randomized_accuracy()
    if not System.__properties.__randomized_accuracy_enabled then return end
    
    local ping_str = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
    local ping = tonumber(ping_str:match("%d+")) or 0
    
    local new_accuracy
    if ping >= 90 then
        new_accuracy = 4
    elseif ping <= 50 then
        new_accuracy = math.random(70, 100)
    else
        new_accuracy = System.__properties.__accuracy
    end
    
    if new_accuracy then
        System.__properties.__accuracy = new_accuracy
        update_divisor()
    end
end

task.spawn(function()
    while task.wait(1) do
        if System.__properties.__randomized_accuracy_enabled then
            update_randomized_accuracy()
        end
    end
end)

-- Initialize getgenv() variables from reference
getgenv().AutoParryMode = "Remote"
getgenv().AutoParryNotify = false
getgenv().CooldownProtection = false
getgenv().AutoAbility = false
getgenv().BallVelocityAbove800 = false

-- SISTEMA DE BYPASS
local DualBypassSystem = {
    __properties = {
        __captured_data = nil,
        __first_parry_done = false,
        __test_bypass_enabled = true,
        __use_virtual_input_once = true,
        __virtual_input_used = false,
        __original_metatables = {},
        __active_hooks = {}
    }
}

function DualBypassSystem.isValidRemoteArgs(args)
    return #args == 7 and
        type(args[2]) == "string" and
        type(args[3]) == "number" and
        typeof(args[4]) == "CFrame" and
        type(args[5]) == "table" and
        type(args[6]) == "table" and
        type(args[7]) == "boolean"
end

function DualBypassSystem.hookRemote(remote)
    if not DualBypassSystem.__properties.__original_metatables[getrawmetatable(remote)] then
        DualBypassSystem.__properties.__original_metatables[getrawmetatable(remote)] = true
        local meta = getrawmetatable(remote)
        setreadonly(meta, false)

        local oldIndex = meta.__index
        meta.__index = function(self, key)
            if (key == "FireServer" and self:IsA("RemoteEvent")) or
               (key == "InvokeServer" and self:IsA("RemoteFunction")) then
                return function(obj, ...)
                    local args = {...}
                    if DualBypassSystem.isValidRemoteArgs(args) and not DualBypassSystem.__properties.__captured_data then
                        DualBypassSystem.__properties.__captured_data = {
                            remote = obj,
                            args = args
                        }
                    end
                    
                    if DualBypassSystem.isValidRemoteArgs(args) and not revertedRemotes[obj] then
                        revertedRemotes[obj] = args
                        Parry_Key = args[2]
                    end
                    
                    return oldIndex(self, key)(obj, unpack(args))
                end
            end
            return oldIndex(self, key)
        end
        setreadonly(meta, true)
    end
end

for _, remote in pairs(ReplicatedStorage:GetChildren()) do
    if remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction") then
        DualBypassSystem.hookRemote(remote)
    end
end

ReplicatedStorage.ChildAdded:Connect(function(child)
    if child:IsA("RemoteEvent") or child:IsA("RemoteFunction") then
        DualBypassSystem.hookRemote(child)
    end
end)

function DualBypassSystem.execute_test_bypass()
    if not DualBypassSystem.__properties.__captured_data or not DualBypassSystem.__properties.__test_bypass_enabled then
        return
    end

    local captured = DualBypassSystem.__properties.__captured_data
    local remote = captured.remote
    local original_args = captured.args
    
    local camera = workspace.CurrentCamera
    local event_data = {}
    
    if Alive then
        for _, entity in pairs(Alive:GetChildren()) do
            if entity.PrimaryPart then
                local success, screen_point = pcall(function()
                    return camera:WorldToScreenPoint(entity.PrimaryPart.Position)
                end)
                if success then
                    event_data[entity.Name] = screen_point
                end
            end
        end
    end
    
    local is_mobile = UserInputService.TouchEnabled and not UserInputService.MouseEnabled
    local final_aim_target
    
    if is_mobile then
        local viewport = camera.ViewportSize
        final_aim_target = {viewport.X / 2, viewport.Y / 2}
    else
        local success, mouse = pcall(function()
            return UserInputService:GetMouseLocation()
        end)
        if success then
            final_aim_target = {mouse.X, mouse.Y}
        else
            final_aim_target = {0, 0}
        end
    end
    
    local modified_args = {
        original_args[1],
        original_args[2],
        original_args[3],
        camera.CFrame,
        event_data,
        final_aim_target,
        original_args[7]
    }
    
    pcall(function()
        if remote:IsA('RemoteEvent') then
            remote:FireServer(unpack(modified_args))
        elseif remote:IsA('RemoteFunction') then
            remote:InvokeServer(unpack(modified_args))
        end
    end)
end

System.animation = {}

function System.animation.play_grab_parry()
    if not System.__properties.__play_animation then
        return
    end
    
    local character = LocalPlayer.Character
    if not character then return end
    
    local humanoid = character:FindFirstChildOfClass('Humanoid')
    local animator = humanoid and humanoid:FindFirstChildOfClass('Animator')
    if not humanoid or not animator then return end
    
    local sword_name
    if getgenv().skinChangerEnabled then
        sword_name = getgenv().swordAnimations
    else
        sword_name = character:GetAttribute('CurrentlyEquippedSword')
    end
    if not sword_name then return end
    
    local sword_api = ReplicatedStorage.Shared.SwordAPI.Collection
    local parry_animation = sword_api.Default:FindFirstChild('GrabParry')
    if not parry_animation then return end
    
    local sword_data = ReplicatedStorage.Shared.ReplicatedInstances.Swords.GetSword:Invoke(sword_name)
    if not sword_data or not sword_data['AnimationType'] then return end
    
    for _, object in pairs(sword_api:GetChildren()) do
        if object.Name == sword_data['AnimationType'] then
            if object:FindFirstChild('GrabParry') or object:FindFirstChild('Grab') then
                local animation_type = object:FindFirstChild('GrabParry') and 'GrabParry' or 'Grab'
                parry_animation = object[animation_type]
            end
        end
    end
    
    if System.__properties.__grab_animation and System.__properties.__grab_animation.IsPlaying then
        System.__properties.__grab_animation:Stop()
    end
    
    System.__properties.__grab_animation = animator:LoadAnimation(parry_animation)
    System.__properties.__grab_animation.Priority = Enum.AnimationPriority.Action4
    System.__properties.__grab_animation:Play()
end

System.ball = {}

function System.ball.get()
    local balls = workspace:FindFirstChild('Balls')
    if not balls then return nil end
    
    for _, ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute('realBall') then
            ball.CanCollide = false
            return ball
        end
    end
    return nil
end

function System.ball.get_all()
    local balls_table = {}
    local balls = workspace:FindFirstChild('Balls')
    if not balls then return balls_table end
    
    for _, ball in pairs(balls:GetChildren()) do
        if ball:GetAttribute('realBall') then
            ball.CanCollide = false
            table.insert(balls_table, ball)
        end
    end
    return balls_table
end

function System.ball.get_distance(ball, player)
    if not ball or not player then return math.huge end
    
    local ball_pos = ball.Position
    local player_pos = player.Position
    
    return (ball_pos - player_pos).Magnitude
end

function System.ball.is_targeting(ball, player)
    if not ball or not player then return false end
    
    local ball_target = ball:GetAttribute('target')
    if not ball_target then return false end
    
    -- Check if ball is targeting the player
    if ball_target == LocalPlayer.Name then
        return true
    end
    
    -- Also check if ball is heading towards player
    local ball_velocity = ball.AssemblyLinearVelocity
    if ball_velocity.Magnitude == 0 then return false end
    
    local ball_direction = ball_velocity.Unit
    local to_player = (player.Position - ball.Position).Unit
    
    local dot = ball_direction:Dot(to_player)
    return dot > 0.7 -- Ball is heading towards player
end

System.player = {}

function System.player.get()
    local character = LocalPlayer.Character
    if not character then return nil end
    
    local root = character:FindFirstChild('HumanoidRootPart')
    return root or character.PrimaryPart
end

local Closest_Entity = nil
local last_closest_check = 0

function System.player.get_closest()
    local now = tick()
    if now - last_closest_check < 0.1 then
        return Closest_Entity
    end
    last_closest_check = now

    local max_distance = math.huge
    local closest_entity = nil
    
    if not Alive then return nil end
    
    for _, entity in pairs(Alive:GetChildren()) do
        if entity ~= LocalPlayer.Character then
            if entity.PrimaryPart then
                local distance = LocalPlayer:DistanceFromCharacter(entity.PrimaryPart.Position)
                if distance < max_distance then
                    max_distance = distance
                    closest_entity = entity
                end
            end
        end
    end
    
    Closest_Entity = closest_entity
    return closest_entity
end

function System.player.get_closest_to_cursor()
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild('HumanoidRootPart') then
        return nil
    end
    
    local closest_player = nil
    local minimal_dot = -math.huge
    local camera = workspace.CurrentCamera
    
    if not Alive then return nil end
    
    local success, mouse_location = pcall(function()
        return UserInputService:GetMouseLocation()
    end)
    
    if not success then return nil end
    
    local ray = camera:ScreenPointToRay(mouse_location.X, mouse_location.Y)
    local pointer = CFrame.lookAt(ray.Origin, ray.Origin + ray.Direction)
    
    for _, player in pairs(Alive:GetChildren()) do
        if player == LocalPlayer.Character then continue end
        if not player:FindFirstChild('HumanoidRootPart') then continue end
        
        local direction = (player.HumanoidRootPart.Position - camera.CFrame.Position).Unit
        local dot = pointer.LookVector:Dot(direction)
        
        if dot > minimal_dot then
            minimal_dot = dot
            closest_player = player
        end
    end
    
    return closest_player
end

System.curve = {}

function System.curve.get_cframe()
    local camera = workspace.CurrentCamera
    local root = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild('HumanoidRootPart')
    if not root then return camera.CFrame end
    
    local targetPart
    local closest = System.player.get_closest_to_cursor()
    if closest and closest:FindFirstChild('HumanoidRootPart') then
        targetPart = closest.HumanoidRootPart
    end
    
    local target_pos = targetPart and targetPart.Position or (root.Position + camera.CFrame.LookVector * 100)
    
    local curve_functions = {
        function() return camera.CFrame end,
        
        function()
            local direction = (target_pos - root.Position).Unit
            local random_offset
            local attempts = 0
            repeat
                random_offset = Vector3.new(
                    math.random(-4000, 4000),
                    math.random(-4000, 4000),
                    math.random(-4000, 4000)
                )
                local curve_direction = (target_pos + random_offset - root.Position).Unit
                local dot = direction:Dot(curve_direction)
                attempts = attempts + 1
            until dot < 0.95 or attempts > 10
            return CFrame.new(root.Position, target_pos + random_offset)
        end,
        
        function()
            return CFrame.new(root.Position, target_pos + Vector3.new(0, 5, 0))
        end,
        
        function()
            local direction = (root.Position - target_pos).Unit
            local backwards_pos = root.Position + direction * 10000 + Vector3.new(0, 1000, 0)
            return CFrame.new(camera.CFrame.Position, backwards_pos)
        end,
        
        function()
            return CFrame.new(root.Position, target_pos + Vector3.new(0, -9e18, 0))
        end,
        
        function()
            return CFrame.new(root.Position, target_pos + Vector3.new(0, 9e18, 0))
        end
    }
    
    return curve_functions[System.__properties.__curve_mode]()
end

function System.curve.calculate_enhanced(ball, player, velocity, timing_multiplier)
    -- Enhanced curve calculation for high velocity balls
    local current_pos = ball.Position
    local current_velocity = ball.AssemblyLinearVelocity
    local player_pos = player.Position
    
    -- Predict ball position based on velocity and timing
    local time_to_impact = (current_pos - player_pos).Magnitude / velocity
    local predicted_pos = current_pos + current_velocity * (time_to_impact * timing_multiplier)
    
    -- Apply curve mode to predicted position
    local curve_offset = System.curve.calculate_curve_offset(predicted_pos, player_pos, velocity)
    local final_position = predicted_pos + curve_offset
    
    return final_position
end

function System.curve.calculate_curve_offset(ball_pos, player_pos, velocity)
    -- Calculate curve offset based on velocity and distance
    local distance = (ball_pos - player_pos).Magnitude
    local velocity_factor = math.min(velocity / 500, 2.0)
    
    -- Different curve patterns based on curve mode
    local curve_modes = {
        function() -- Camera
            return Vector3.new(0, 0, 0)
        end,
        function() -- Random
            return Vector3.new(
                math.random(-distance * 0.1, distance * 0.1),
                math.random(-distance * 0.05, distance * 0.05),
                math.random(-distance * 0.1, distance * 0.1)
            ) * velocity_factor
        end,
        function() -- Accelerated
            local direction = (player_pos - ball_pos).Unit
            return direction * (distance * 0.2 * velocity_factor)
        end,
        function() -- Backwards
            local direction = (ball_pos - player_pos).Unit
            return direction * (distance * 0.3 * velocity_factor)
        end,
        function() -- Slow
            return Vector3.new(0, -distance * 0.1 * velocity_factor, 0)
        end,
        function() -- High
            return Vector3.new(0, distance * 0.2 * velocity_factor, 0)
        end
    }
    
    return curve_modes[System.__properties.__curve_mode]()
end

System.detection = {}

function System.detection.is_curved(ball)
    local velocity = ball.AssemblyLinearVelocity
    local direction = velocity.Unit
    
    local future_position = ball.Position + direction * 10
    local future_velocity = ball.AssemblyLinearVelocity
    
    local angle = math.acos(direction:Dot(future_velocity.Unit))
    
    return angle > 0.1
end

System.parry = {}

function System.parry.execute(target_position)
    -- Enhanced parry execution with double parry prevention
    local current_time = tick()
    
    -- Check cooldown to prevent double parrying
    if System.__properties.__double_parry_prevention and 
       (current_time - System.__properties.__last_parry_time) < System.__properties.__parry_cooldown then
        return
    end
    
    -- Additional safety check: Don't parry if too close to another player
    local char = LocalPlayer.Character
    if char and char.PrimaryPart then
        local closest_entity = System.player.get_closest()
        if closest_entity and closest_entity.PrimaryPart then
            local entity_distance = char:DistanceFromCharacter(closest_entity.PrimaryPart.Position)
            if entity_distance < System.__properties.__min_parry_distance then
                return -- Too close to another player, skip parry
            end
        end
    end
    
    if System.__properties.__parries > 10000 or not LocalPlayer.Character then
        return
    end
    
    -- Update last parry time
    System.__properties.__last_parry_time = current_time
    
    if not System.__properties.__first_parry_done and DualBypassSystem.__properties.__use_virtual_input_once 
       and not DualBypassSystem.__properties.__virtual_input_used then
        System.__properties.__first_parry_done = true
        DualBypassSystem.__properties.__virtual_input_used = true
        print("🎮 VirtualInput usado para primeiro parry (sem Block Button)")
        
        task.wait(0.1)
    end

    local camera = workspace.CurrentCamera
    local success, mouse = pcall(function()
        return UserInputService:GetMouseLocation()
    end)
    
    if not success then return end
    
    local vec2_mouse = {mouse.X, mouse.Y}
    local is_mobile = System.__properties.__is_mobile
    
    local event_data = {}
    if Alive then
        for _, entity in pairs(Alive:GetChildren()) do
            if entity.PrimaryPart then
                local success2, screen_point = pcall(function()
                    return camera:WorldToScreenPoint(entity.PrimaryPart.Position)
                end)
                if success2 then
                    event_data[entity.Name] = screen_point
                end
            end
        end
    end
    
    -- Use target position if provided, otherwise use curve cframe
    local target_cframe
    if target_position then
        target_cframe = CFrame.lookAt(camera.CFrame.Position, target_position)
    else
        target_cframe = System.curve.get_cframe()
    end

    local final_aim_target
    if is_mobile then
        local viewport = camera.ViewportSize
        final_aim_target = {viewport.X / 2, viewport.Y / 2}
    else
        final_aim_target = vec2_mouse
    end

    print("Executing parry with target: " .. tostring(target_position))

    local remote_count = 0
    for remote, original_args in pairs(revertedRemotes) do
        remote_count = remote_count + 1
        local modified_args = {
            original_args[1],
            original_args[2],
            original_args[3],
            target_cframe,
            event_data,
            final_aim_target,
            original_args[7]
        }
        
        pcall(function()
            if remote:IsA('RemoteEvent') then
                remote:FireServer(unpack(modified_args))
            elseif remote:IsA('RemoteFunction') then
                remote:InvokeServer(unpack(modified_args))
            end
        end)
    end
    
    if remote_count == 0 then
        print("No remotes captured yet - using test bypass")
        DualBypassSystem.execute_test_bypass()
    else
        print("Parry executed through " .. remote_count .. " remotes")
    end
    
    if DualBypassSystem.__properties.__test_bypass_enabled and DualBypassSystem.__properties.__captured_data then
        DualBypassSystem.execute_test_bypass()
    end
    
    if System.__properties.__parries > 10000 then return end
    
    System.__properties.__parries = System.__properties.__parries + 1
    task.delay(0.5, function()
        if System.__properties.__parries > 0 then
            System.__properties.__parries = System.__properties.__parries - 1
        end
    end)
end

function System.parry.keypress()
    -- Enhanced keypress with double parry prevention
    local current_time = tick()
    
    -- Check cooldown to prevent double parrying
    if System.__properties.__double_parry_prevention and 
       (current_time - System.__properties.__last_parry_time) < System.__properties.__parry_cooldown then
        return
    end
    
    -- Additional safety check: Don't parry if too close to another player
    local char = LocalPlayer.Character
    if char and char.PrimaryPart then
        local closest_entity = System.player.get_closest()
        if closest_entity and closest_entity.PrimaryPart then
            local entity_distance = char:DistanceFromCharacter(closest_entity.PrimaryPart.Position)
            if entity_distance < System.__properties.__min_parry_distance then
                return -- Too close to another player, skip parry
            end
        end
    end
    
    if System.__properties.__parries > 10000 or not LocalPlayer.Character then
        return
    end
    
    -- Update last parry time
    System.__properties.__last_parry_time = current_time

    local camera = workspace.CurrentCamera
    local curve_cframe = System.curve.get_cframe()
    local event_data = {}
    
    if Alive then
        for _, entity in pairs(Alive:GetChildren()) do
            if entity.PrimaryPart then
                local success2, screen_point = pcall(function()
                    return camera:WorldToScreenPoint(entity.PrimaryPart.Position)
                end)
                if success2 then
                    event_data[entity.Name] = screen_point
                end
            end
        end
    end
    
    local is_mobile = System.__properties.__is_mobile
    local final_aim_target
    
    if is_mobile then
        local viewport = camera.ViewportSize
        final_aim_target = {viewport.X / 2, viewport.Y / 2}
    else
        local success, mouse = pcall(function()
            return UserInputService:GetMouseLocation()
        end)
        if success then
            final_aim_target = {mouse.X, mouse.Y}
        else
            final_aim_target = {0, 0}
        end
    end
    
    for remote, original_args in pairs(revertedRemotes) do
        local modified_args = {
            original_args[1],
            original_args[2],
            original_args[3],
            curve_cframe,
            event_data,
            final_aim_target,
            original_args[7]
        }
        
        pcall(function()
            if remote:IsA('RemoteEvent') then
                remote:FireServer(unpack(modified_args))
            elseif remote:IsA('RemoteFunction') then
                remote:InvokeServer(unpack(modified_args))
            end
        end)
    end
    
    if System.__properties.__parries > 10000 then return end
    
    System.__properties.__parries = System.__properties.__parries + 1
    task.delay(0.5, function()
        if System.__properties.__parries > 0 then
            System.__properties.__parries = System.__properties.__parries - 1
        end
    end)
end

function System.parry.execute_action()
    System.animation.play_grab_parry()
    System.parry.execute()
end

local function linear_predict(a, b, t)
    return a + (b - a) * t
end

System.detection = {
    __ball_properties = {
        __aerodynamic_time = tick(),
        __last_warping = tick(),
        __lerp_radians = 0,
        __curving = tick()
    }
}

function System.detection.is_curved_enhanced(ball, velocity)
    -- Enhanced curve detection for high velocity balls (up to 1M speed)
    local current_velocity = ball.AssemblyLinearVelocity
    local current_direction = current_velocity.Unit
    local speed = current_velocity.Magnitude
    
    -- Adaptive check distances based on velocity - more aggressive for high speeds
    local check_distances
    if speed > System.__config.__settings.__extreme_velocity_threshold then
        check_distances = {1, 2, 3, 4} -- Very close checks for extreme speeds
    elseif speed > System.__config.__settings.__high_velocity_threshold then
        check_distances = {2, 4, 6, 8} -- Close checks for high speeds
    else
        check_distances = {3, 6, 9, 12} -- Standard checks
    end
    
    local curve_samples = {}
    
    for _, distance in ipairs(check_distances) do
        local future_position = ball.Position + current_direction * distance
        local future_velocity = ball.AssemblyLinearVelocity
        local future_direction = future_velocity.Unit
        
        local angle = math.acos(math.clamp(current_direction:Dot(future_direction), -1, 1))
        table.insert(curve_samples, angle)
    end
    
    -- Calculate weighted average curve angle with more aggressive weighting for high speeds
    local total_curve = 0
    local total_weight = 0
    for i, angle in ipairs(curve_samples) do
        local weight
        if speed > System.__config.__settings.__extreme_velocity_threshold then
            weight = (6 - i) * 2 -- Double weight for extreme speeds
        elseif speed > System.__config.__settings.__high_velocity_threshold then
            weight = (5 - i) * 1.5 -- 1.5x weight for high speeds
        else
            weight = (5 - i) -- Standard weight
        end
        total_curve = total_curve + angle * weight
        total_weight = total_weight + weight
    end
    local average_curve = total_curve / total_weight
    
    -- Much more aggressive threshold based on velocity
    local curve_threshold
    if speed > System.__config.__settings.__extreme_velocity_threshold then
        curve_threshold = math.max(0.005, 0.02 - (speed / 1000000)) -- Very sensitive for extreme speeds
    elseif speed > System.__config.__settings.__high_velocity_threshold then
        curve_threshold = math.max(0.01, 0.04 - (speed / 400000)) -- Sensitive for high speeds
    else
        curve_threshold = math.max(0.03, 0.08 - (velocity / 15000)) -- Standard but more sensitive
    end
    
    return average_curve > curve_threshold
end

function System.detection.is_curved()
    local props = System.detection.__ball_properties
    local ball = System.ball.get()
    if not ball then return false end

    local zoomies = ball:FindFirstChild("zoomies")
    if not zoomies then return false end

    local velocity = zoomies.VectorVelocity
    local speed = velocity.Magnitude
    if speed < 1 then return false end

    local ball_dir = velocity.Unit
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end

    local pos = char.PrimaryPart.Position
    local direction = (pos - ball.Position).Unit
    local dot = direction:Dot(ball_dir)

    local ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue() / 1000
    local distance = (pos - ball.Position).Magnitude
    local reach_time = distance / speed - ping

    local dot_threshold = 0.55 - (ping * 0.75)
    dot_threshold = math.clamp(dot_threshold, -1, 0.45)

    local speed_threshold = math.min(speed / 100, 45)
    local ball_distance_threshold = 15 - math.min(distance / 1000, 15) + speed_threshold

    local clamped_dot = math.clamp(dot, -1, 1)
    local radians = math.asin(clamped_dot)
    props.__lerp_radians = linear_predict(props.__lerp_radians, radians, 0.85)

    if props.__lerp_radians < 0.016 then
        props.__last_warping = tick()
    end

    if distance < (ball_distance_threshold * 0.85) then
        return false
    end

    local sudden_curve = (tick() - props.__last_warping) < (reach_time / 1.4)
    if sudden_curve then
        return true
    end

    local sustained_curve = (tick() - props.__curving) < (reach_time / 1.1)
    if sustained_curve then
        return true
    end

    return dot < dot_threshold
end

System.triggerbot = {}

function System.triggerbot.trigger(ball)
    if System.__triggerbot.__is_parrying or System.__triggerbot.__parries > System.__triggerbot.__max_parries then
        return
    end
    
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and 
       LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then
        return
    end
    
    System.__triggerbot.__is_parrying = true
    System.__triggerbot.__parries = System.__triggerbot.__parries + 1
    
    System.animation.play_grab_parry()
    System.parry.execute()
    
    task.delay(System.__triggerbot.__parry_delay, function()
        if System.__triggerbot.__parries > 0 then
            System.__triggerbot.__parries = System.__triggerbot.__parries - 1
        end
    end)
    
    local connection
    connection = ball:GetAttributeChangedSignal('target'):Once(function()
        System.__triggerbot.__is_parrying = false
        if connection then
            connection:Disconnect()
        end
    end)
    
    task.spawn(function()
        local start_time = tick()
        repeat
            RunService.Heartbeat:Wait()
        until (tick() - start_time >= 1 or not System.__triggerbot.__is_parrying)
        
        System.__triggerbot.__is_parrying = false
    end)
end

function System.triggerbot.loop()
    if not System.__triggerbot.__enabled then return end
    
    if LocalPlayer.Character and LocalPlayer.Character.PrimaryPart and 
       LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then
        return
    end
    
    local balls = workspace:FindFirstChild('Balls')
    if not balls then return end
    
    for _, ball in pairs(balls:GetChildren()) do
        if ball:IsA('BasePart') and ball:GetAttribute('target') == LocalPlayer.Name then
            System.triggerbot.trigger(ball)
            break
        end
    end
end

function System.triggerbot.enable(enabled)
    System.__triggerbot.__enabled = enabled
    
    if enabled then
        if not System.__properties.__connections.__triggerbot then
            System.__properties.__connections.__triggerbot = RunService.Heartbeat:Connect(System.triggerbot.loop)
        end
    else
        if System.__properties.__connections.__triggerbot then
            System.__properties.__connections.__triggerbot:Disconnect()
            System.__properties.__connections.__triggerbot = nil
        end
        System.__triggerbot.__is_parrying = false
        System.__triggerbot.__parries = 0
    end
end

System.manual_spam = {}

local manualSpamThread = nil

function System.manual_spam.start()
    System.manual_spam.stop()

    System.__properties.__manual_spam_enabled = true

    local parry_keypress = System.parry.keypress
    local parry_execute = System.parry.execute
    local play_animation = System.animation.play_grab_parry

    local threshold = 0.015

    manualSpamThread = coroutine.create(function()
        local last_spam = 0

        while System.__properties.__manual_spam_enabled do
            local now = os.clock()

            if now - last_spam >= threshold then
                last_spam = now

                if getgenv().ManualSpamMode == "Keypress" then
                    parry_keypress()
                else
                    parry_execute()
                    if getgenv().ManualSpamAnimationFix then
                        play_animation()
                    end
                end
            end

            coroutine.yield()
        end
    end)

    task.spawn(function()
        while System.__properties.__manual_spam_enabled
            and manualSpamThread
            and coroutine.status(manualSpamThread) ~= "dead" do

            coroutine.resume(manualSpamThread)
            task.wait()
        end
    end)
end

function System.manual_spam.stop()
    System.__properties.__manual_spam_enabled = false
    manualSpamThread = nil
    
    -- Also stop the GUI spam if it's running
    ManualSpamGUI.__is_spamming = false
    ManualSpamGUI.stop_spamming()
end

System.auto_spam = {}

local autoSpamThread = nil

function System.auto_spam.start()
    if System.__properties.__connections.__auto_spam_connection then
        System.__properties.__connections.__auto_spam_connection:Disconnect()
    end
    
    System.__properties.__auto_spam_enabled = true
    
    local last_auto_spam = 0
    local last_target_check = 0
    local event = RunService.Heartbeat
    
    -- Cache de funções e serviços para performance
    local get_ball = System.ball.get
    local get_closest = System.player.get_closest
    local parry_keypress = System.parry.keypress
    local parry_execute = System.parry.execute
    local play_animation = System.animation.play_grab_parry
    
    System.__properties.__connections.__auto_spam_connection = event:Connect(function()
        local char = LocalPlayer.Character
        if not System.__properties.__auto_spam_enabled or not char or char.Parent ~= Alive then
            return
        end
        
        local now = tick()
        local threshold = 0.008 -- Reduced from 0.015 for faster response
        if now - last_auto_spam < threshold then return end
        last_auto_spam = now
            
        local ball = get_ball()
        if not ball then return end
        
        local zoomies = ball:FindFirstChild('zoomies')
        if not zoomies then return end
        
        -- Otimização: Não busca o player mais próximo a cada frame, apenas a cada 0.05s (faster)
        if now - last_target_check > 0.05 then
            get_closest()
            last_target_check = now
            
            if System.__properties.__spam_target then
                local target = System.__properties.__spam_target
                if not target.Parent or not target:FindFirstChild("Humanoid") or target.Humanoid.Health <= 0 then
                    System.__properties.__spam_target = nil
                    System.__properties.__spam_target_time = 0
                end
            end
            
            if not System.__properties.__spam_target or (now - System.__properties.__spam_target_time > 0.5) then -- Faster target switching
                System.__properties.__spam_target = Closest_Entity
                System.__properties.__spam_target_time = now
            end
        end
        
        local ball_target = ball:GetAttribute('target')
        if not ball_target then return end
        
        local ball_properties = System.auto_spam:get_ball_properties()
        local entity_properties = System.auto_spam:get_entity_properties()
        
        if ball_properties and entity_properties then
            local ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue()
            local ping_threshold = math.clamp(ping / 3, 1, 16) -- More aggressive ping compensation
            
            local spam_accuracy = System.auto_spam.spam_service({
                Ball_Properties = ball_properties,
                Entity_Properties = entity_properties,
                Ping = ping_threshold
            })
            
            if spam_accuracy > 0 then
                local root = char.PrimaryPart
                if not root then return end
                
                local target_entity = Closest_Entity
                if not target_entity or not target_entity.PrimaryPart then return end
                
                local target_pos = target_entity.PrimaryPart.Position
                local target_dist = (root.Position - target_pos).Magnitude
                
                local ball_pos = ball.Position
                local dist_to_ball = (root.Position - ball_pos).Magnitude
                
                local shouldSpam = false
                local spam_target = System.__properties.__spam_target
                if spam_target then
                    if ball_target == spam_target.Name or ball_target == LocalPlayer.Name then
                        shouldSpam = true
                    end
                end
                
                -- Enhanced safety check: Don't spam if too close to prevent dying
                if shouldSpam and not char:GetAttribute('Pulsed') then
                    local closest_entity = System.player.get_closest()
                    if closest_entity and closest_entity.PrimaryPart then
                        local entity_distance = char:DistanceFromCharacter(closest_entity.PrimaryPart.Position)
                        if entity_distance < System.__properties.__min_parry_distance then
                            return -- Too close to another player, skip spam to prevent dying
                        end
                    end
                    
                    if target_dist <= spam_accuracy and dist_to_ball <= spam_accuracy then
                        local multiplier = System.__properties.__auto_spam_distance_multiplier or 1.0
                        local max_allowed_dist = 40 * multiplier -- Increased from 35 for better range
                        
                        local is_target = (ball_target == LocalPlayer.Name)
                        local final_max_dist = is_target and max_allowed_dist or (max_allowed_dist * 0.9) -- Slightly less for non-targets
                        
                        if target_dist <= final_max_dist and dist_to_ball <= final_max_dist then
                            if System.__properties.__parries > System.__properties.__spam_threshold then
                                if getgenv().AutoSpamMode == "Keypress" then
                                    parry_keypress()
                                else
                                    parry_execute()
                                    if getgenv().AutoSpamAnimationFix then
                                        play_animation()
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

function System.auto_spam.stop()
    System.__properties.__auto_spam_enabled = false
    System.__properties.__spam_target = nil
    System.__properties.__spam_target_time = 0
    autoSpamThread = nil
end

function System.auto_spam:get_entity_properties()
    local entity = Closest_Entity
    if not entity or not entity.PrimaryPart then return false end
    
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end
    
    local root_pos = char.PrimaryPart.Position
    local entity_pos = entity.PrimaryPart.Position
    local diff = root_pos - entity_pos
    
    return {
        Velocity = entity.PrimaryPart.Velocity,
        Direction = diff.Unit,
        Distance = diff.Magnitude
    }
end

function System.auto_spam:get_ball_properties()
    local ball = System.ball.get()
    if not ball then return false end
    
    local char = LocalPlayer.Character
    if not char or not char.PrimaryPart then return false end
    
    local ball_pos = ball.Position
    local root_pos = char.PrimaryPart.Position
    local diff = root_pos - ball_pos
    
    local ball_velocity = ball.AssemblyLinearVelocity or Vector3.zero
    
    return {
        Velocity = ball_velocity,
        Direction = diff.Unit,
        Distance = diff.Magnitude,
        Dot = diff.Unit:Dot(ball_velocity.Unit)
    }
end

function System.auto_spam.spam_service(self)
    local ball = System.ball.get()
    local entity = System.player.get_closest()
    
    if not ball or not entity or not entity.PrimaryPart then
        return false
    end
    
    local spam_accuracy = 0
    
    local velocity = ball.AssemblyLinearVelocity or Vector3.zero
    local speed = velocity.Magnitude
    
    local direction = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Unit
    local dot = direction:Dot(velocity.Unit)
    
    local target_position = entity.PrimaryPart.Position
    local target_distance = LocalPlayer:DistanceFromCharacter(target_position)
    
    local multiplier = System.__properties.__auto_spam_distance_multiplier or 1.0
    local base_distance = 30 * multiplier
    local maximum_spam_distance = (self.Ping + math.min(speed / 4, 60)) * multiplier
    
    if self.Entity_Properties.Distance > maximum_spam_distance and self.Entity_Properties.Distance > base_distance then
        return 0
    end
    
    if self.Ball_Properties.Distance > maximum_spam_distance and self.Ball_Properties.Distance > base_distance then
        return 0
    end
    
    if target_distance > maximum_spam_distance and target_distance > base_distance then
        return 0
    end
    
    local maximum_speed =  7 - math.min(speed / 5, 5)
    local maximum_dot = math.clamp(dot, -1, 1) * maximum_speed
    
    spam_accuracy = maximum_spam_distance - maximum_dot
    
    return spam_accuracy
end

System.autoparry = {}

function System.autoparry.start()
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
    end
    
    print("Starting Auto Parry system...")
    
    System.__properties.__connections.__autoparry = RunService.PreSimulation:Connect(function()
        if not System.__properties.__autoparry_enabled or not LocalPlayer.Character or 
           not LocalPlayer.Character.PrimaryPart then
            return
        end
        
        local balls = System.ball.get_all()
        local one_ball = System.ball.get()
        
        -- Enhanced training balls detection
        local training_ball = nil
        if workspace:FindFirstChild("TrainingBalls") then
            for _, Instance in pairs(workspace.TrainingBalls:GetChildren()) do
                if Instance:GetAttribute("realBall") then
                    training_ball = Instance
                    break
                end
            end
        end

        for _, ball in pairs(balls) do
            if System.__triggerbot.__enabled then return end
            if getgenv().BallVelocityAbove800 then return end
            if not ball then continue end
            
            local zoomies = ball:FindFirstChild('zoomies')
            if not zoomies then continue end
            
            ball:GetAttributeChangedSignal('target'):Once(function()
                System.__properties.__parried = false
            end)
            
            if System.__properties.__parried then continue end
            
            local ball_target = ball:GetAttribute('target')
            local velocity = zoomies.VectorVelocity
            local distance = (LocalPlayer.Character.PrimaryPart.Position - ball.Position).Magnitude
            
            local ping = Stats.Network.ServerStatsItem['Data Ping']:GetValue() / 10
            local ping_threshold = math.clamp(ping / 10, 5, 17)
            local speed = velocity.Magnitude
            
            local capped_speed_diff = math.min(math.max(speed - 9.5, 0), 650)
            local speed_divisor = (2.4 + capped_speed_diff * 0.002) * System.__properties.__divisor_multiplier
            local parry_accuracy = ping_threshold + math.max(speed / speed_divisor, 9.5)
            
            local curved = System.detection.is_curved()
            
            if ball:FindFirstChild('AeroDynamicSlashVFX') then
                ball.AeroDynamicSlashVFX:Destroy()
                System.__properties.__tornado_time = tick()
            end
            
            if Runtime:FindFirstChild('Tornado') then
                if (tick() - System.__properties.__tornado_time) < 
                   (Runtime.Tornado:GetAttribute('TornadoTime') or 1) + 0.314159 then
                    continue
                end
            end
            
            if one_ball and one_ball:GetAttribute('target') == LocalPlayer.Name and curved then
                continue
            end
            
            if ball:FindFirstChild('ComboCounter') then continue end
            
            if LocalPlayer.Character.PrimaryPart:FindFirstChild('SingularityCape') then continue end
            
            if System.__config.__detections.__infinity and System.__properties.__infinity_active then continue end
            if System.__config.__detections.__deathslash and System.__properties.__deathslash_active then continue end
            if System.__config.__detections.__timehole and System.__properties.__timehole_active then continue end
            if System.__config.__detections.__slashesoffury and System.__properties.__slashesoffury_active then continue end
            
            if ball_target == LocalPlayer.Name and distance <= parry_accuracy then
                if getgenv().AutoAbility then
                    local AbilityCD = LocalPlayer.PlayerGui.Hotbar.Ability.UIGradient
                    if AbilityCD and AbilityCD.Offset.Y == 0.5 then
                        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Abilities") then
                            local abilities = LocalPlayer.Character.Abilities
                            if (abilities:FindFirstChild("Raging Deflection") and abilities["Raging Deflection"].Enabled) or
                               (abilities:FindFirstChild("Rapture") and abilities["Rapture"].Enabled) or
                               (abilities:FindFirstChild("Calming Deflection") and abilities["Calming Deflection"].Enabled) or
                               (abilities:FindFirstChild("Aerodynamic Slash") and abilities["Aerodynamic Slash"].Enabled) or
                               (abilities:FindFirstChild("Fracture") and abilities["Fracture"].Enabled) or
                               (abilities:FindFirstChild("Death Slash") and abilities["Death Slash"].Enabled) then
                                System.__properties.__parried = true
                                ReplicatedStorage.Remotes.AbilityButtonPress:Fire()
                                task.wait(2.432)
                                ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DeathSlashShootActivation"):FireServer(true)
                                continue
                            end
                        end
                    end
                end
            end
            
            if ball_target == LocalPlayer.Name and distance <= parry_accuracy then
                if getgenv().AutoParryMode == "Keypress" then
                    System.parry.keypress()
                else
                    System.parry.execute_action()
                end
                
                System.__properties.__parried = true
                task.delay(0.5, function()
                    System.__properties.__parried = false
                end)
                break
            end
        end
    end)
end

-- Event connections for detection
ReplicatedStorage.Remotes.DeathBall.OnClientEvent:Connect(function(c, d)
    System.__properties.__deathslash_active = d or false
end)

ReplicatedStorage.Remotes.InfinityBall.OnClientEvent:Connect(function(a, b)
    System.__properties.__infinity_active = b or false
end)

ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/TimeHoleActivate"].OnClientEvent:Connect(function(...)
    local args = {...}
    local player = args[1]
    
    if player == LocalPlayer or player == LocalPlayer.Name or (player and player.Name == LocalPlayer.Name) then
        System.__properties.__timehole_active = true
    end
end)

ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/TimeHoleDeactivate"].OnClientEvent:Connect(function()
    System.__properties.__timehole_active = false
end)

local maxParryCount = 36
local parryDelay = 0.05

ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/SlashesOfFuryActivate"].OnClientEvent:Connect(function(...)
    local args = {...}
    local player = args[1]
    
    if player == LocalPlayer or player == LocalPlayer.Name or (player and player.Name == LocalPlayer.Name) then
        System.__properties.__slashesoffury_active = true
        System.__properties.__slashesoffury_count = 0
    end
end)

ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/SlashesOfFuryEnd"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_active = false
    System.__properties.__slashesoffury_count = 0
end)

ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/SlashesOfFuryParry"].OnClientEvent:Connect(function()
    System.__properties.__slashesoffury_count = System.__properties.__slashesoffury_count + 1
end)

ReplicatedStorage.Packages._Index["sleitnick_net@0.1.0"].net["RE/SlashesOfFuryCatch"].OnClientEvent:Connect(function()
    spawn(function()
        while System.__properties.__slashesoffury_active and System.__properties.__slashesoffury_count < maxParryCount do
            if System.__config.__detections.__slashesoffury then
                System.parry.execute()
                task.wait(parryDelay)
            else
                break
            end
        end
    end)
end)

local ThemeName = "Crimson"


local Window = WindUI:CreateWindow({
    Title = "BURAT HUB",
    Author = "Blade Ball",
    Icon = "solar:three-squares-bold-duotone",
    Theme = ThemeName,
    NewElements = true,
    
    OpenButton = {
        Title = "BURAT HUB",
        CornerRadius = UDim.new(1,0),
        StrokeThickness = 3,
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
        Scale = 0.7,
        
        Color = ColorSequence.new(
            Color3.fromHex("#FF3030"), 
            Color3.fromHex("#FF6060")
        )
    },
    Topbar = {
        Height = 44,
        ButtonsType = "Mac",
        Buttons = {
            Minimize = {
                Icon = "solar:three-squares-bold-duotone",
                Callback = function(self)
                    Window:Minimize()
                end
            }
        }
    },
})

local Tab1 = Window:Tab({
    Title = "Main",
    Icon = "solar:home-2-bold",
})

Tab1:Select()


Tab1:Section({
    Title = "Auto Parry",
    Desc = "Automatically parry the ball",
})

Tab1:Space({ Columns = 1 })

Tab1:Toggle({
    Title = "Auto Parry",
    Desc = "Enable automatic parrying",
    Value = false,
    Callback = function(Value)
        System.__properties.__autoparry_enabled = Value
        print("Auto Parry toggled:", Value, "Enabled:", System.__properties.__autoparry_enabled)
        if Value then
            System.autoparry.start()
        else
            if System.__properties.__connections.__autoparry then
                System.__properties.__connections.__autoparry:Disconnect()
                System.__properties.__connections.__autoparry = nil
            end
        end
    end,
})

Tab1:Space({ Columns = 1 })

Tab1:Dropdown({
    Title = "Curve Mode",
    Desc = "Select curve detection mode",
    Values = {"Camera", "Random", "Accelerated", "Backwards", "Slow", "High"},
    Value = "Camera",
    Callback = function(Value)
        local curveModes = {
            ["Camera"] = 1,
            ["Random"] = 2,
            ["Accelerated"] = 3,
            ["Backwards"] = 4,
            ["Slow"] = 5,
            ["High"] = 6
        }
        System.__properties.__curve_mode = curveModes[Value] or 1
    end,
})

Tab1:Space({ Columns = 1 })

Tab1:Toggle({
    Title = "Play Animation",
    Desc = "Play parry animation",
    Value = false,
    Callback = function(Value)
        System.__properties.__play_animation = Value
    end,
})

Tab1:Space({ Columns = 1 })

Tab1:Section({
    Title = "Parry Accuracy",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
})

Tab1:Space({ Columns = 1 })

Tab1:Slider({
    IsTooltip = true,
    Step = 1,
    Value = {
        Min = 1,
        Max = 100,
        Default = 50,
    },
    Icons = {
        From = "solar:bolt-circle-bold-duotone",
        To = "solar:bolt-circle-bold",
    },
    Callback = function(value)
        System.__properties.__accuracy = value
        update_divisor()
    end
})

local Tab2 = Window:Tab({
    Title = "Spam",
    Icon = "solar:bolt-bold-duotone",
})

Tab2:Section({
    Title = "Spam Controls",
    Desc = "Manual and automatic spam controls",
})

Tab2:Space({ Columns = 1 })

Tab2:Toggle({
    Title = "Manual Spam",
    Desc = "Enable manual spam functionality",
    Value = false,
    Callback = function(Value)
        if Value then
            System.manual_spam.start()
            ManualSpamGUI.toggle(true) -- Enable GUI/keybind when manual spam is enabled
        else
            System.manual_spam.stop()
            ManualSpamGUI.toggle(false) -- Disable GUI/keybind when manual spam is disabled
        end
    end,
})

Tab2:Space({ Columns = 1 })

Tab2:Keybind({
    Title = "Manual Spam Keybind",
    Desc = "Press key to set manual spam toggle (PC only)",
    Value = "F",
    Callback = function(key)
        ManualSpamGUI.set_keybind(key)
    end
})

Tab2:Space({ Columns = 1 })

Tab2:Toggle({
    Title = "Auto Spam",
    Desc = "Enable automatic spam functionality",
    Value = false,
    Callback = function(Value)
        if Value then
            System.auto_spam.start()
        else
            System.auto_spam.stop()
        end
    end,
})

Tab2:Space({ Columns = 1 })

Tab2:Section({
    Title = "Spam Settings",
    TextSize = 16,
    FontWeight = Enum.FontWeight.SemiBold,
})

Tab2:Space({ Columns = 1 })

Tab2:Slider({
    IsTooltip = true,
    Step = 0.1,
    Value = {
        Min = 0.5,
        Max = 3.0,
        Default = 1.5,
    },
    Icons = {
        From = "solar:shield-bold",
        To = "solar:shield-check-bold",
    },
    Callback = function(value)
        System.__properties.__spam_threshold = value
    end
})

local Tab3 = Window:Tab({
    Title = "Detection",
    Icon = "solar:eye-bold",
})

Tab3:Section({
    Title = "Ability Detection",
    Desc = "Detect and handle special abilities",
})

Tab3:Space({ Columns = 1 })

Tab3:Toggle({
    Title = "Infinity Detection",
    Desc = "Detect and handle Infinity ability",
    Value = true,
    Callback = function(Value)
        System.__config.__detections.__infinity = Value
    end,
})

Tab3:Space({ Columns = 1 })

Tab3:Toggle({
    Title = "Death Slash Detection",
    Desc = "Detect and handle Death Slash ability",
    Value = true,
    Callback = function(Value)
        System.__config.__detections.__deathslash = Value
    end,
})

Tab3:Space({ Columns = 1 })

Tab3:Toggle({
    Title = "Time Hole Detection",
    Desc = "Detect and handle Time Hole ability",
    Value = true,
    Callback = function(Value)
        System.__config.__detections.__timehole = Value
    end,
})

Tab3:Space({ Columns = 1 })

Tab3:Toggle({
    Title = "Slashes of Fury Detection",
    Desc = "Detect and handle Slashes of Fury ability",
    Value = true,
    Callback = function(Value)
        System.__config.__detections.__slashesoffury = Value
    end,
})

Tab3:Space({ Columns = 1 })

Tab3:Toggle({
    Title = "Phantom Detection",
    Desc = "Detect and handle Phantom ability",
    Value = false,
    Callback = function(Value)
        System.__config.__detections.__phantom = Value
    end,
})


-- Manual Spam GUI System
local ManualSpamGUI = {}
ManualSpamGUI.__enabled = false
ManualSpamGUI.__gui = nil
ManualSpamGUI.__spam_button = nil
ManualSpamGUI.__keybind = Enum.KeyCode.F
ManualSpamGUI.__connection = nil
ManualSpamGUI.__keybind_connection = nil
ManualSpamGUI.__is_spamming = false

function ManualSpamGUI.create_gui()
    if ManualSpamGUI.__gui then
        ManualSpamGUI.__gui:Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "ManualSpamGUI"
    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local Frame = Instance.new("Frame")
    Frame.Name = "Main"
    Frame.Parent = ScreenGui
    Frame.Size = UDim2.new(0, 120, 0, 120)
    Frame.Position = UDim2.new(1, -130, 1, -130)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.BorderSizePixel = 0
    Frame.BackgroundTransparency = 0.2
    Frame.Draggable = true
    
    local UICorner = Instance.new("UICorner")
    UICorner.Parent = Frame
    UICorner.CornerRadius = UDim.new(0, 12)
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Parent = Frame
    Stroke.Color = Color3.fromRGB(255, 100, 100)
    Stroke.Thickness = 2
    Stroke.Transparency = 0.3
    
    local SpamButton = Instance.new("TextButton")
    SpamButton.Name = "SpamButton"
    SpamButton.Parent = Frame
    SpamButton.Size = UDim2.new(0, 100, 0, 100)
    SpamButton.Position = UDim2.new(0, 10, 0, 10)
    SpamButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    SpamButton.BorderSizePixel = 0
    SpamButton.Text = "SPAM"
    SpamButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    SpamButton.TextScaled = true
    SpamButton.Font = Enum.Font.GothamBold
    
    local ButtonCorner = Instance.new("UICorner")
    ButtonCorner.Parent = SpamButton
    ButtonCorner.CornerRadius = UDim.new(0, 8)
    
    -- Mobile touch events
    SpamButton.TouchBegan:Connect(function()
        ManualSpamGUI.__is_spamming = true
        SpamButton.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
        
        -- Start spamming
        ManualSpamGUI.start_spamming()
    end)
    
    SpamButton.TouchEnded:Connect(function()
        ManualSpamGUI.__is_spamming = false
        SpamButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        
        -- Stop spamming
        ManualSpamGUI.stop_spamming()
    end)
    
    -- PC mouse events
    SpamButton.MouseButton1Down:Connect(function()
        ManualSpamGUI.__is_spamming = true
        SpamButton.BackgroundColor3 = Color3.fromRGB(255, 150, 50)
        
        -- Start spamming
        ManualSpamGUI.start_spamming()
    end)
    
    SpamButton.MouseButton1Up:Connect(function()
        ManualSpamGUI.__is_spamming = false
        SpamButton.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
        
        -- Stop spamming
        ManualSpamGUI.stop_spamming()
    end)
    
    ManualSpamGUI.__gui = ScreenGui
    ManualSpamGUI.__spam_button = SpamButton
end

function ManualSpamGUI.start_spamming()
    if ManualSpamGUI.__connection then
        ManualSpamGUI.__connection:Disconnect()
    end
    
    ManualSpamGUI.__connection = RunService.Heartbeat:Connect(function()
        if ManualSpamGUI.__is_spamming and System.__properties.__manual_spam_enabled then
            System.parry.execute()
        end
    end)
end

function ManualSpamGUI.stop_spamming()
    ManualSpamGUI.__is_spamming = false -- Reset spamming state
    if ManualSpamGUI.__connection then
        ManualSpamGUI.__connection:Disconnect()
        ManualSpamGUI.__connection = nil
    end
    
    -- Update button color if GUI exists
    if ManualSpamGUI.__spam_button then
        ManualSpamGUI.__spam_button.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
    end
end

function ManualSpamGUI.setup_keybind()
    -- Remove any existing connection to prevent duplicates
    if ManualSpamGUI.__keybind_connection then
        ManualSpamGUI.__keybind_connection:Disconnect()
        ManualSpamGUI.__keybind_connection = nil
    end
    
    ManualSpamGUI.__keybind_connection = UserInputService.InputBegan:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        
        if input.KeyCode == ManualSpamGUI.__keybind then
            -- Only work if manual spam is enabled and system is active
            if ManualSpamGUI.__enabled and System.__properties.__manual_spam_enabled then
                if not ManualSpamGUI.__is_spamming then
                    ManualSpamGUI.__is_spamming = true
                    ManualSpamGUI.start_spamming()
                else
                    ManualSpamGUI.__is_spamming = false
                    ManualSpamGUI.stop_spamming()
                end
            end
        end
    end)
end

function ManualSpamGUI.set_keybind(key)
    if type(key) == "string" then
        ManualSpamGUI.__keybind = Enum.KeyCode[key]
    else
        ManualSpamGUI.__keybind = key
    end
end

function ManualSpamGUI.toggle(enabled)
    ManualSpamGUI.__enabled = enabled
    
    if enabled then
        if System.__properties.__is_mobile then
            ManualSpamGUI.create_gui() -- Show GUI for mobile
        else
            ManualSpamGUI.setup_keybind() -- Setup keybind for PC
        end
    else
        if ManualSpamGUI.__gui then
            ManualSpamGUI.__gui:Destroy()
            ManualSpamGUI.__gui = nil
        end
        ManualSpamGUI.stop_spamming()
    end
end

Window:OnUnload(function()
    -- Stop all systems when UI is unloaded
    
    -- Stop auto parry
    System.__properties.__autoparry_enabled = false
    if System.__properties.__connections.__autoparry then
        System.__properties.__connections.__autoparry:Disconnect()
        System.__properties.__connections.__autoparry = nil
    end
    
    -- Stop manual spam
    System.manual_spam.stop()
    ManualSpamGUI.toggle(false)
    
    -- Stop auto spam
    System.auto_spam.stop()
    
    -- Stop performance monitor
    PerformanceMonitor.toggle(false)
    
    -- Reset all states
    System.__properties.__parried = false
    System.__properties.__parries = 0
    System.__properties.__last_parry_time = 0
    
    -- Clear all connections
    for name, connection in pairs(System.__properties.__connections) do
        if connection then
            connection:Disconnect()
            System.__properties.__connections[name] = nil
        end
    end
    
    -- Clear manual spam keybind connection
    if ManualSpamGUI.__keybind_connection then
        ManualSpamGUI.__keybind_connection:Disconnect()
        ManualSpamGUI.__keybind_connection = nil
    end
    
    -- Reset spam targets
    System.__properties.__spam_target = nil
    System.__properties.__spam_target_time = 0
end)

-- Initialize keybind setup
ManualSpamGUI.setup_keybind()

-- Fixed LeftCtrl keybind for minimizing window
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == Enum.KeyCode.LeftControl then
        -- Minimize/restore the window
        if Window and Window.Minimize then
            Window:Minimize()
        end
    end
end)

-- Settings Tab
-- Performance Monitor GUI System
local PerformanceMonitor = {}
PerformanceMonitor.__enabled = false
PerformanceMonitor.__gui = nil
PerformanceMonitor.__fps_counter = 0
PerformanceMonitor.__fps_time = 0
PerformanceMonitor.__last_frame_time = tick()

function PerformanceMonitor.create_gui()
    if PerformanceMonitor.__gui then
        PerformanceMonitor.__gui:Destroy()
    end
    
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "PerformanceMonitor"
    ScreenGui.Parent = game:GetService("CoreGui")
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    local Frame = Instance.new("Frame")
    Frame.Name = "Main"
    Frame.Parent = ScreenGui
    Frame.Size = UDim2.new(0, 200, 0, 80)
    Frame.Position = UDim2.new(0, 10, 0, 10)
    Frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Frame.BorderSizePixel = 0
    Frame.BackgroundTransparency = 0.2
    
    local UICorner = Instance.new("UICorner")
    UICorner.Parent = Frame
    UICorner.CornerRadius = UDim.new(0, 8)
    
    local Stroke = Instance.new("UIStroke")
    Stroke.Parent = Frame
    Stroke.Color = Color3.fromRGB(255, 255, 255)
    Stroke.Thickness = 1
    Stroke.Transparency = 0.5
    
    local PingLabel = Instance.new("TextLabel")
    PingLabel.Name = "PingLabel"
    PingLabel.Parent = Frame
    PingLabel.Size = UDim2.new(1, 0, 0, 25)
    PingLabel.Position = UDim2.new(0, 0, 0, 10)
    PingLabel.BackgroundTransparency = 1
    PingLabel.Text = "Ping: 0ms"
    PingLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    PingLabel.TextScaled = true
    PingLabel.Font = Enum.Font.Gotham
    
    local FPSLabel = Instance.new("TextLabel")
    FPSLabel.Name = "FPSLabel"
    FPSLabel.Parent = Frame
    FPSLabel.Size = UDim2.new(1, 0, 0, 25)
    FPSLabel.Position = UDim2.new(0, 0, 0, 45)
    FPSLabel.BackgroundTransparency = 1
    FPSLabel.Text = "FPS: 0"
    FPSLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    FPSLabel.TextScaled = true
    FPSLabel.Font = Enum.Font.Gotham
    
    PerformanceMonitor.__gui = ScreenGui
    PerformanceMonitor.__ping_label = PingLabel
    PerformanceMonitor.__fps_label = FPSLabel
end

function PerformanceMonitor.update_stats()
    if not PerformanceMonitor.__enabled or not PerformanceMonitor.__gui then return end
    
    -- Update Ping
    local ping = 0
    pcall(function()
        ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValue()
    end)
    
    -- Update FPS
    local current_time = tick()
    local delta_time = current_time - PerformanceMonitor.__last_frame_time
    PerformanceMonitor.__last_frame_time = current_time
    
    PerformanceMonitor.__fps_counter = PerformanceMonitor.__fps_counter + 1
    PerformanceMonitor.__fps_time = PerformanceMonitor.__fps_time + delta_time
    
    local fps = 0
    if PerformanceMonitor.__fps_time >= 1 then
        fps = math.floor(PerformanceMonitor.__fps_counter / PerformanceMonitor.__fps_time)
        PerformanceMonitor.__fps_counter = 0
        PerformanceMonitor.__fps_time = 0
    end
    
    -- Update labels
    if PerformanceMonitor.__ping_label then
        PerformanceMonitor.__ping_label.Text = string.format("Ping: %dms", ping)
        
        -- Color code ping
        if ping < 50 then
            PerformanceMonitor.__ping_label.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green
        elseif ping < 100 then
            PerformanceMonitor.__ping_label.TextColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
        else
            PerformanceMonitor.__ping_label.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red
        end
    end
    
    if PerformanceMonitor.__fps_label and fps > 0 then
        PerformanceMonitor.__fps_label.Text = string.format("FPS: %d", fps)
        
        -- Color code FPS
        if fps >= 60 then
            PerformanceMonitor.__fps_label.TextColor3 = Color3.fromRGB(0, 255, 0) -- Green
        elseif fps >= 30 then
            PerformanceMonitor.__fps_label.TextColor3 = Color3.fromRGB(255, 255, 0) -- Yellow
        else
            PerformanceMonitor.__fps_label.TextColor3 = Color3.fromRGB(255, 0, 0) -- Red
        end
    end
end

function PerformanceMonitor.toggle(enabled)
    PerformanceMonitor.__enabled = enabled
    
    if enabled then
        PerformanceMonitor.create_gui()
    else
        if PerformanceMonitor.__gui then
            PerformanceMonitor.__gui:Destroy()
            PerformanceMonitor.__gui = nil
        end
    end
end

-- Update loop
RunService.Heartbeat:Connect(function()
    PerformanceMonitor.update_stats()
end)

-- Create Settings tab immediately after Performance Monitor
local Tab4 = Window:Tab({
    Title = "Settings",
    Icon = "solar:settings-bold",
})

print("Settings tab created - should be visible now")

Tab4:Section({
    Title = "Performance Monitor",
    Desc = "Display real-time ping and FPS",
})

Tab4:Space({ Columns = 1 })

Tab4:Toggle({
    Title = "Show Performance Monitor",
    Desc = "Display ping and FPS overlay",
    Value = false,
    Callback = function(value)
        PerformanceMonitor.toggle(value)
        print("Performance Monitor toggled:", value)
    end
})

Tab4:Space({ Columns = 2 })

Tab4:Section({
    Title = "Configuration Management",
    Desc = "Save and load your settings",
})

Tab4:Space({ Columns = 1 })

Tab4:Input({
    Title = "Config Name",
    Desc = "Enter a name for your configuration",
    Placeholder = "MyConfig",
    Callback = function(value)
        getgenv().ConfigName = value
    end,
})

Tab4:Space({ Columns = 1 })

Tab4:Button({
    Title = "Save Config",
    Desc = "Save current settings to file",
    Icon = "solar:disk-bold",
    Justify = "Center",
    Callback = function()
        local configName = getgenv().ConfigName or "default"
        local config = {
            autoparry_enabled = System.__properties.__autoparry_enabled,
            triggerbot_enabled = System.__properties.__triggerbot_enabled,
            manual_spam_enabled = System.__properties.__manual_spam_enabled,
            auto_spam_enabled = System.__properties.__auto_spam_enabled,
            play_animation = System.__properties.__play_animation,
            curve_mode = System.__properties.__curve_mode,
            accuracy = System.__properties.__accuracy,
            detections = {
                infinity = System.__config.__detections.__infinity,
                deathslash = System.__config.__detections.__deathslash,
                timehole = System.__config.__detections.__timehole,
                slashesoffury = System.__config.__detections.__slashesoffury,
                phantom = System.__config.__detections.__phantom
            },
            getgenv_settings = {
                AutoParryMode = getgenv().AutoParryMode,
                AutoParryNotify = getgenv().AutoParryNotify,
                CooldownProtection = getgenv().CooldownProtection,
                AutoAbility = getgenv().AutoAbility,
                BallVelocityAbove800 = getgenv().BallVelocityAbove800
            }
        }
        
        local success, error = pcall(function()
            writefile(configName .. "_config.json", game:GetService("HttpService"):JSONEncode(config))
        end)
        
        if success then
            print("Config saved as: " .. configName .. "_config.json")
        else
            print("Failed to save config: " .. tostring(error))
        end
    end,
})

Tab4:Space({ Columns = 1 })

Tab4:Button({
    Title = "Load Config",
    Desc = "Load settings from file",
    Icon = "solar:folder-with-files-bold",
    Justify = "Center",
    Callback = function()
        local configName = getgenv().ConfigName or "default"
        
        local success, content = pcall(function()
            return readfile(configName .. "_config.json")
        end)
        
        if success then
            local config = game:GetService("HttpService"):JSONDecode(content)
            
            -- Apply System properties
            System.__properties.__autoparry_enabled = config.autoparry_enabled or false
            System.__properties.__triggerbot_enabled = config.triggerbot_enabled or false
            System.__properties.__manual_spam_enabled = config.manual_spam_enabled or false
            System.__properties.__auto_spam_enabled = config.auto_spam_enabled or false
            System.__properties.__play_animation = config.play_animation or false
            System.__properties.__curve_mode = config.curve_mode or 1
            System.__properties.__accuracy = config.accuracy or 50
            
            -- Apply detection settings
            if config.detections then
                System.__config.__detections.__infinity = config.detections.infinity or false
                System.__config.__detections.__deathslash = config.detections.deathslash or false
                System.__config.__detections.__timehole = config.detections.timehole or false
                System.__config.__detections.__slashesoffury = config.detections.slashesoffury or false
                System.__config.__detections.__phantom = config.detections.phantom or false
            end
            
            -- Apply getgenv settings
            if config.getgenv_settings then
                getgenv().AutoParryMode = config.getgenv_settings.AutoParryMode or "Remote"
                getgenv().AutoParryNotify = config.getgenv_settings.AutoParryNotify or false
                getgenv().CooldownProtection = config.getgenv_settings.CooldownProtection or false
                getgenv().AutoAbility = config.getgenv_settings.AutoAbility or false
                getgenv().BallVelocityAbove800 = config.getgenv_settings.BallVelocityAbove800 or false
            end
            
            update_divisor()
            print("Config loaded: " .. configName .. "_config.json")
        else
            print("Failed to load config: " .. tostring(error))
        end
    end,
})

Tab4:Space({ Columns = 1 })

Tab4:Button({
    Title = "Delete Config",
    Desc = "Delete saved configuration file",
    Icon = "solar:trash-bin-trash-bold",
    Justify = "Center",
    Callback = function()
        local configName = getgenv().ConfigName or "default"
        
        local success, error = pcall(function()
            delfile(configName .. "_config.json")
        end)
        
        if success then
            print("Config deleted: " .. configName .. "_config.json")
        else
            print("Failed to delete config: " .. tostring(error))
        end
    end,
})

Tab4:Space({ Columns = 1 })

Tab4:Section({
    Title = "UI Settings",
    Desc = "User interface options",
})

Tab4:Space({ Columns = 1 })

Tab4:Button({
    Title = "Destroy UI",
    Desc = "Close the user interface",
    Icon = "solar:close-square-bold",
    Justify = "Center",
    Callback = function()
        Window:Destroy()
    end,
})

Tab4:Space({ Columns = 1 })

Tab4:Button({
    Title = "Copy Discord Link",
    Desc = "Copy support Discord invite",
    Icon = "solar:link-bold",
    Justify = "Center",
    Callback = function()
        setclipboard("https://discord.gg/example")
        print("Discord link copied to clipboard!")
    end,
})
