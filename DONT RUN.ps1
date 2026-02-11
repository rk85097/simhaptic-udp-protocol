# SimHaptic Full Demo - Automated Flight Sequence
# Demonstrates ALL haptic effects in a realistic 2-3 minute flight cycle

$Host.UI.RawUI.WindowTitle = "SimHaptic Full Demo"

$targetIP = "127.0.0.1"
$targetPort = 19872
$updateRate = 30

$udpClient = New-Object System.Net.Sockets.UdpClient
$endpoint = New-Object System.Net.IPEndPoint ([System.Net.IPAddress]::Parse($targetIP), $targetPort)

$script:state = @{
    sh = 1
    aircraftTitle = "F/A-18C Hornet"
    acType = "military"
    engineType = "Jet"
    surfaceType = "Steel_mats"
    batteryState = $false
    hasRetractableGear = $true
    hasFloats = $false
    isParkingBrakeSet = $true
    isFuelPumpOn = $false
    isTowConnected = $false
    canopyJettison = $false
    isCannonFireOn = $false
    isAutoFlapsOn = $false
    isStalling = $false
    isInCockpit = $true
    agl = 0.0
    ias = 0.0
    groundSpeed = 0.0
    vso = 130.0
    vne = 800.0
    gforce = 1.0
    verticalSpeed = 0.0
    stallPercentage = 0.0
    windshieldWindVelocity = 0.0
    densityAltFt = 29.92
    acPitch = 0.0
    acRoll = 0.0
    relativeYaw = 0.0
    accX = 0.0
    bodyAccelerationY = 0.0
    gearFrontPosition = 1.0
    gearLeftPosition = 1.0
    gearRightPosition = 1.0
    gearFrontOnGround = $true
    gearLeftOnGround = $true
    gearRightOnGround = $true
    flapsPosition = 0.0
    spoilersPosition = 0.0
    brakes = 0.0
    doorPos = 1.0
    hookPos = 0.0
    wingPos = 0.0
    fuelProbePos = 0.0
    dragChute = 0.0
    yokeX = 0.0
    yokeY = 0.0
    engine1Speed = 0.0
    engine2Speed = 0.0
    engine1Running = $false
    engine2Running = $false
    engine1StarterOn = $false
    engine2StarterOn = $false
    engine1AfterburnerRatio = 0.0
    engine2AfterburnerRatio = 0.0
    engine1ReverseThrust = 0.0
    engine2ReverseThrust = 0.0
    apu = 0.0
    emptyWeight = 23000.0
    totalWeight = 36000.0
    maxGrossWeight = 51900.0
    wingSpanM = 12.3
    collective = 0.0
    rotor1RpmNorm = 0.0
    gunShellsCount = 578
    bombsCount = 0
    fuelTanksCount = 2
    otherItemCount = 0
    missilesCount = 4
    flareCount = 60
    damage = 0.0
}

$script:phase = "idle"
$script:phaseTime = 0.0
$script:totalTime = 0.0
$script:running = $false
$script:packetsSent = 0
$script:activeEffects = @()
$script:phaseDescription = "Press SPACE to start demo"

# Phase definitions - fixed timing
$script:phases = @(
    @{ name = "cold_dark"; duration = 4; desc = "Cold & Dark - Carrier Deck" }
    @{ name = "battery_on"; duration = 5; desc = "Battery & Avionics Power Up" }
    @{ name = "apu_start"; duration = 4; desc = "APU Starting" }
    @{ name = "engine1_start"; duration = 5; desc = "Engine 1 Start Sequence" }
    @{ name = "engine2_start"; duration = 5; desc = "Engine 2 Start Sequence" }
    @{ name = "canopy_close"; duration = 4; desc = "Canopy Closing" }
    @{ name = "taxi_to_cat"; duration = 6; desc = "Taxi to Catapult" }
    @{ name = "cat_tension"; duration = 3; desc = "Catapult Tension - Full Power" }
    @{ name = "catapult_launch"; duration = 3; desc = "CATAPULT LAUNCH!" }
    @{ name = "catapult_airborne"; duration = 2; desc = "Airborne - Climbing" }
    @{ name = "gear_up"; duration = 5; desc = "Gear Retracting" }
    @{ name = "flaps_up"; duration = 5; desc = "Flaps Retracting" }
    @{ name = "climb"; duration = 5; desc = "Climbing to Altitude" }
    @{ name = "cruise"; duration = 3; desc = "Level Cruise Flight" }
    @{ name = "roll_left"; duration = 3; desc = "Banking Left" }
    @{ name = "roll_right"; duration = 4; desc = "Banking Right" }
    @{ name = "roll_center"; duration = 2; desc = "Wings Level" }
    @{ name = "yaw_left"; duration = 3; desc = "Yawing Left" }
    @{ name = "yaw_right"; duration = 4; desc = "Yawing Right" }
    @{ name = "yaw_center"; duration = 2; desc = "Centering Rudder" }
    @{ name = "pitch_up"; duration = 3; desc = "Pitching Up" }
    @{ name = "pitch_down"; duration = 4; desc = "Pitching Down" }
    @{ name = "pitch_center"; duration = 2; desc = "Leveling Off" }
    @{ name = "spoilers_deploy"; duration = 3; desc = "Speed Brake Deploying" }
    @{ name = "spoilers_hold"; duration = 5; desc = "Speed Brake Deployed" }
    @{ name = "spoilers_retract"; duration = 3; desc = "Speed Brake Retracting" }
    @{ name = "high_g_build"; duration = 3; desc = "HIGH-G MANEUVER - Building..." }
    @{ name = "high_g_peak"; duration = 3; desc = "HIGH-G MANEUVER - 8G PULL!" }
    @{ name = "high_g_release"; duration = 3; desc = "HIGH-G MANEUVER - Releasing..." }
    @{ name = "recover"; duration = 2; desc = "Recovering..." }
    @{ name = "missile_launch"; duration = 3; desc = "FOX 2! Missile Away!" }
    @{ name = "gun_burst"; duration = 4; desc = "GUNS GUNS GUNS!" }
    @{ name = "flare_release"; duration = 3; desc = "Deploying Countermeasures" }
    @{ name = "take_damage"; duration = 3; desc = "TAKING FIRE! Aircraft Hit!" }
    @{ name = "drop_tanks"; duration = 3; desc = "Jettisoning External Tanks" }
    @{ name = "turbulence"; duration = 8; desc = "Heavy Turbulence Encounter" }
    @{ name = "stall_approach"; duration = 4; desc = "Approaching Stall - Buffet!" }
    @{ name = "stall_peak"; duration = 3; desc = "FULL STALL! 100%" }
    @{ name = "stall_recovery"; duration = 3; desc = "Stall Recovery" }
    @{ name = "overspeed_dive"; duration = 4; desc = "OVERSPEED WARNING!" }
    @{ name = "approach_setup"; duration = 4; desc = "Setting Up for Approach" }
    @{ name = "gear_down"; duration = 5; desc = "Gear Extending" }
    @{ name = "flaps_deploy"; duration = 3; desc = "Flaps Extending" }
    @{ name = "flaps_hold"; duration = 3; desc = "Flaps Full - Configured" }
    @{ name = "hook_down"; duration = 3; desc = "Tail Hook Down" }
    @{ name = "final_approach"; duration = 5; desc = "Final Approach" }
    @{ name = "touchdown"; duration = 2; desc = "TOUCHDOWN!" }
    @{ name = "rollout"; duration = 5; desc = "Rollout - Braking" }
    @{ name = "taxi_back"; duration = 5; desc = "Taxi to Parking" }
    @{ name = "parking"; duration = 3; desc = "Setting Parking Brake" }
    @{ name = "engine_shutdown"; duration = 5; desc = "Engines Shutting Down" }
    @{ name = "apu_shutdown"; duration = 3; desc = "APU Shutdown" }
    @{ name = "power_down"; duration = 3; desc = "Systems Power Down" }
    @{ name = "complete"; duration = 4; desc = "Demo Complete - Press SPACE to restart" }
)
$script:currentPhaseIndex = -1

function Reset-State {
    $script:state.batteryState = $false
    $script:state.engine1Running = $false
    $script:state.engine2Running = $false
    $script:state.engine1Speed = 0.0
    $script:state.engine2Speed = 0.0
    $script:state.engine1StarterOn = $false
    $script:state.engine2StarterOn = $false
    $script:state.engine1AfterburnerRatio = 0.0
    $script:state.engine2AfterburnerRatio = 0.0
    $script:state.engine1ReverseThrust = 0.0
    $script:state.engine2ReverseThrust = 0.0
    $script:state.apu = 0.0
    $script:state.isParkingBrakeSet = $true
    $script:state.isFuelPumpOn = $false
    $script:state.agl = 0.0
    $script:state.ias = 0.0
    $script:state.groundSpeed = 0.0
    $script:state.gforce = 1.0
    $script:state.verticalSpeed = 0.0
    $script:state.stallPercentage = 0.0
    $script:state.acPitch = 0.0
    $script:state.acRoll = 0.0
    $script:state.accX = 0.0
    $script:state.bodyAccelerationY = 0.0
    $script:state.gearFrontPosition = 1.0
    $script:state.gearLeftPosition = 1.0
    $script:state.gearRightPosition = 1.0
    $script:state.gearFrontOnGround = $true
    $script:state.gearLeftOnGround = $true
    $script:state.gearRightOnGround = $true
    $script:state.flapsPosition = 0.0
    $script:state.spoilersPosition = 0.0
    $script:state.brakes = 0.0
    $script:state.doorPos = 1.0
    $script:state.hookPos = 0.0
    $script:state.dragChute = 0.0
    $script:state.gunShellsCount = 578
    $script:state.missilesCount = 4
    $script:state.flareCount = 60
    $script:state.fuelTanksCount = 2
    $script:state.damage = 0.0
    $script:state.isStalling = $false
    $script:state.isCannonFireOn = $false
    $script:state.canopyJettison = $false
    $script:state.surfaceType = "Steel_mats"
    $script:phase = "idle"
    $script:phaseTime = 0.0
    $script:totalTime = 0.0
    $script:currentPhaseIndex = -1
    $script:running = $false
    $script:activeEffects = @()
    $script:phaseDescription = "Press SPACE to start demo"
}

function Start-Demo {
    Reset-State
    $script:running = $true
    $script:currentPhaseIndex = 0
    $script:phaseTime = 0.0
    $script:totalTime = 0.0
    $script:phase = $script:phases[0].name
    $script:phaseDescription = $script:phases[0].desc
}

function Lerp($from, $to, $t) {
    [double]$f = $from
    [double]$tt = $to
    [double]$clamped = [Math]::Min([Math]::Max($t, 0), 1)
    return $f + (($tt - $f) * $clamped)
}

# Ease in-out function for smooth G transitions
function EaseInOut($t) {
    [double]$clamped = [Math]::Min([Math]::Max([double]$t, 0.0), 1.0)
    if ($clamped -lt 0.5) {
        return [double](2.0 * $clamped * $clamped)
    } else {
        [double]$x = (-2.0 * $clamped) + 2.0
        return [double](1.0 - (($x * $x) / 2.0))
    }
}

function Update-Phase {
    param($dt)
    
    if (-not $script:running) { return }
    
    $script:phaseTime += $dt
    $script:totalTime += $dt
    $script:activeEffects = @()
    
    $currentPhaseDef = $script:phases[$script:currentPhaseIndex]
    $progress = $script:phaseTime / $currentPhaseDef.duration
    
    switch ($script:phase) {
        "cold_dark" {
            # Nothing on - complete cold and dark
            $script:state.batteryState = $false
            $script:state.apu = 0
            $script:activeEffects = @("(No effects - cold & dark)")
        }
        "battery_on" {
            # Battery on, wait before APU - fuel pump not yet
            $script:state.batteryState = $true
            $script:state.isFuelPumpOn = $false
            $script:activeEffects = @("Avionics")
        }
        "apu_start" {
            # Now start APU
            $script:state.apu = Lerp 0 1 $progress
            $script:activeEffects = @("APU Starting")
        }
        "engine1_start" {
            $script:state.apu = 1.0
            $script:state.isFuelPumpOn = $true  # Fuel pump on for engine start
            if ($progress -lt 0.3) {
                $script:state.engine1StarterOn = $true
                $script:state.engine1Speed = Lerp 0 20 ($progress / 0.3)
            } else {
                $script:state.engine1StarterOn = $progress -lt 0.5
                $script:state.engine1Speed = Lerp 20 55 (($progress - 0.3) / 0.7)
                $script:state.engine1Running = $true
            }
            $script:activeEffects = @("Engine Start", "Fuel Pump", "Engine Vibration")
        }
        "engine2_start" {
            $script:state.isFuelPumpOn = $true  # Still on for engine 2 start
            if ($progress -lt 0.3) {
                $script:state.engine2StarterOn = $true
                $script:state.engine2Speed = Lerp 0 20 ($progress / 0.3)
            } else {
                $script:state.engine2StarterOn = $progress -lt 0.5
                $script:state.engine2Speed = Lerp 20 55 (($progress - 0.3) / 0.7)
                $script:state.engine2Running = $true
            }
            $script:activeEffects = @("Engine Start", "Fuel Pump", "Engine Vibration")
        }
        "canopy_close" {
            $script:state.doorPos = Lerp 1 0 $progress
            $script:state.engine1Speed = 55
            $script:state.engine2Speed = 55
            $script:state.isFuelPumpOn = $false  # Engines stable, pump off
            $script:activeEffects = @("Door/Canopy Movement", "Engine Vibration")
        }
        "taxi_to_cat" {
            $script:state.doorPos = 0
            $script:state.isParkingBrakeSet = $false
            $script:state.groundSpeed = 8 + (Get-Random -Minimum -1 -Maximum 2)
            $script:state.engine1Speed = 60
            $script:state.engine2Speed = 60
            $script:state.bodyAccelerationY = (Get-Random -Minimum -5 -Maximum 5) / 100.0
            $script:state.surfaceType = "Steel_mats"
            $script:activeEffects = @("Ground Roll", "Ground Bumps", "Engine Vibration")
        }
        "cat_tension" {
            # Building up for catapult - full power, brakes holding
            $script:state.groundSpeed = 0
            $script:state.brakes = 1.0
            $script:state.engine1Speed = 100
            $script:state.engine2Speed = 100
            $script:state.engine1AfterburnerRatio = Lerp 0 1 $progress
            $script:state.engine2AfterburnerRatio = Lerp 0 1 $progress
            $script:state.flapsPosition = 0.5
            $script:state.isFuelPumpOn = $true  # Boost pump on for takeoff
            # Gear still on ground
            $script:state.gearFrontOnGround = $true
            $script:state.gearLeftOnGround = $true
            $script:state.gearRightOnGround = $true
            $script:state.accX = 0  # Not launched yet
            $script:activeEffects = @("Engine Vibration", "Afterburner", "Fuel Pump", "Engine Rumble")
        }
        "catapult_launch" {
            # CATAPULT! accX > 1.4G required, gear MUST be on ground
            $script:state.brakes = 0
            $script:state.engine1AfterburnerRatio = 1.0
            $script:state.engine2AfterburnerRatio = 1.0
            # Keep gear on ground for catapult detection
            $script:state.gearFrontOnGround = $true
            $script:state.gearLeftOnGround = $true
            $script:state.gearRightOnGround = $true
            $script:state.agl = 0
            # accX must be > 1.4G for catapult effect
            $script:state.accX = Lerp 1.5 2.8 $progress
            $script:state.groundSpeed = Lerp 0 160 $progress
            $script:state.ias = $script:state.groundSpeed * 0.95
            $script:state.gforce = Lerp 1 2.5 $progress
            $script:activeEffects = @("CATAPULT LAUNCH! (accX > 1.4G)", "Afterburner", "G-Force")
        }
        "catapult_airborne" {
            # Now we leave the deck
            $script:state.accX = Lerp 2.8 0.5 $progress
            $script:state.gearFrontOnGround = $false
            $script:state.gearLeftOnGround = $false
            $script:state.gearRightOnGround = $false
            $script:state.agl = Lerp 0 200 $progress
            $script:state.verticalSpeed = 3000
            $script:state.ias = 180
            $script:state.groundSpeed = 190
            $script:state.acPitch = 15
            $script:state.gforce = Lerp 2.5 1.5 $progress
            $script:activeEffects = @("Climbing", "Afterburner", "Engine Vibration")
        }
        "gear_up" {
            $script:state.accX = 0
            $script:state.agl = Lerp 200 800 $progress
            $script:state.ias = 250
            $script:state.groundSpeed = 270
            $script:state.verticalSpeed = 3000
            $script:state.acPitch = 15
            $script:state.gforce = 1.2
            # Gradual gear retraction
            $script:state.gearFrontPosition = Lerp 1 0 $progress
            $script:state.gearLeftPosition = Lerp 1 0 $progress
            $script:state.gearRightPosition = Lerp 1 0 $progress
            $script:state.engine1AfterburnerRatio = 0.5
            $script:state.engine2AfterburnerRatio = 0.5
            $script:activeEffects = @("Gear Retracting", "Gear Drag", "Afterburner")
        }
        "flaps_up" {
            $script:state.agl = Lerp 800 3000 $progress
            $script:state.ias = 300
            $script:state.groundSpeed = 320
            $script:state.verticalSpeed = 2500
            $script:state.gearFrontPosition = 0
            $script:state.gearLeftPosition = 0
            $script:state.gearRightPosition = 0
            # Gradual flaps retraction
            $script:state.flapsPosition = Lerp 0.5 0 $progress
            $script:state.engine1AfterburnerRatio = 0.3
            $script:state.engine2AfterburnerRatio = 0.3
            $script:activeEffects = @("Flaps Retracting", "Flaps Drag", "Engine Vibration")
        }
        "climb" {
            $script:state.agl = Lerp 3000 15000 $progress
            $script:state.ias = 350
            $script:state.groundSpeed = 400
            $script:state.verticalSpeed = 4000
            $script:state.acPitch = 20
            $script:state.flapsPosition = 0
            $script:state.engine1AfterburnerRatio = 0
            $script:state.engine2AfterburnerRatio = 0
            $script:state.engine1Speed = 85
            $script:state.engine2Speed = 85
            $script:activeEffects = @("Engine Vibration", "Airframe Airflow")
        }
        "cruise" {
            $script:state.agl = 15000
            $script:state.ias = 450
            $script:state.groundSpeed = 520
            $script:state.verticalSpeed = 0
            $script:state.acPitch = 2
            $script:state.acRoll = 0
            $script:state.gforce = 1.0
            $script:state.isFuelPumpOn = $false  # Stable cruise, pump off
            $script:state.yokeX = 0
            $script:state.yokeY = 0
            $script:state.relativeYaw = 0
            $script:state.stallPercentage = 0
            $script:state.bodyAccelerationY = 0
            $script:activeEffects = @("Engine Vibration", "Airframe Airflow")
        }
        "roll_left" {
            # Gradual roll to 45 degrees left (negative)
            [double]$eased = EaseInOut $progress
            $script:state.agl = 15000
            $script:state.ias = 450
            $script:state.groundSpeed = 520
            $script:state.verticalSpeed = 0
            $script:state.acPitch = 2
            $script:state.acRoll = [double](-45.0 * $eased)
            $script:state.yokeX = [double](-0.6 * $eased)
            [double]$rollAbs = [Math]::Abs([double]$script:state.acRoll)
            $script:state.gforce = [double](1.0 + (0.4 * $rollAbs / 45.0))
            $script:state.bodyAccelerationY = [double](-0.15 * $eased)
            $script:activeEffects = @("Roll Left", "Aileron Input", "G-Force: $([Math]::Round($script:state.gforce, 1))G")
        }
        "roll_right" {
            # Roll from -45 through center to +45 degrees right
            [double]$eased = EaseInOut $progress
            $script:state.acRoll = [double]((-45.0) + (90.0 * $eased))
            $script:state.yokeX = [double]((-0.6) + (1.2 * $eased))
            [double]$rollAbs = [Math]::Abs([double]$script:state.acRoll)
            $script:state.gforce = [double](1.0 + (0.4 * $rollAbs / 45.0))
            $script:state.bodyAccelerationY = [double]((-0.15) + (0.3 * $eased))
            $script:activeEffects = @("Roll Right", "Aileron Input", "G-Force: $([Math]::Round($script:state.gforce, 1))G")
        }
        "roll_center" {
            # Return to wings level
            [double]$eased = EaseInOut $progress
            $script:state.acRoll = [double](45.0 * (1.0 - $eased))
            $script:state.yokeX = [double](0.6 * (1.0 - $eased))
            $script:state.gforce = [double](1.0 + (0.4 * (1.0 - $eased)))
            $script:state.bodyAccelerationY = [double](0.15 * (1.0 - $eased))
            $script:activeEffects = @("Wings Level", "Centering Ailerons")
        }
        "yaw_left" {
            # Gradual yaw left with rudder
            [double]$eased = EaseInOut $progress
            $script:state.acRoll = 0.0
            $script:state.yokeX = 0.0
            $script:state.relativeYaw = [double](-15.0 * $eased)
            $script:state.acPitch = 2.0
            $script:state.bodyAccelerationY = [double](-0.1 * $eased)
            $script:state.gforce = 1.0
            $script:activeEffects = @("Yaw Left", "Rudder Input", "Sideslip")
        }
        "yaw_right" {
            # Yaw from left through center to right
            [double]$eased = EaseInOut $progress
            $script:state.relativeYaw = [double]((-15.0) + (30.0 * $eased))
            $script:state.bodyAccelerationY = [double]((-0.1) + (0.2 * $eased))
            $script:activeEffects = @("Yaw Right", "Rudder Input", "Sideslip")
        }
        "yaw_center" {
            # Return to centered
            [double]$eased = EaseInOut $progress
            $script:state.relativeYaw = [double](15.0 * (1.0 - $eased))
            $script:state.bodyAccelerationY = [double](0.1 * (1.0 - $eased))
            $script:activeEffects = @("Centering Rudder", "Stabilizing")
        }
        "pitch_up" {
            # Gradual pitch up
            [double]$eased = EaseInOut $progress
            $script:state.relativeYaw = 0.0
            $script:state.acPitch = [double](2.0 + (18.0 * $eased))
            $script:state.yokeY = [double](0.5 * $eased)
            $script:state.verticalSpeed = [double](2000.0 * $eased)
            $script:state.gforce = [double](1.0 + (0.8 * $eased))
            $script:state.ias = [double](450.0 - (50.0 * $eased))
            $script:state.agl = [double](15000.0 + (500.0 * $progress))
            $script:activeEffects = @("Pitch Up", "Elevator Input", "G-Force: $([Math]::Round($script:state.gforce, 1))G")
        }
        "pitch_down" {
            # Pitch from up through level to down
            [double]$eased = EaseInOut $progress
            $script:state.acPitch = [double](20.0 - (35.0 * $eased))
            $script:state.yokeY = [double](0.5 - (0.9 * $eased))
            $script:state.verticalSpeed = [double](2000.0 - (4500.0 * $eased))
            $script:state.gforce = [double](1.8 - (1.3 * $eased))
            $script:state.ias = [double](400.0 + (80.0 * $eased))
            $script:state.agl = [double](15500.0 - (1000.0 * $progress))
            $script:activeEffects = @("Pitch Down", "Elevator Input", "G-Force: $([Math]::Round($script:state.gforce, 1))G")
        }
        "pitch_center" {
            # Return to level flight
            [double]$eased = EaseInOut $progress
            $script:state.acPitch = [double]((-15.0) + (17.0 * $eased))
            $script:state.yokeY = [double]((-0.4) + (0.4 * $eased))
            $script:state.verticalSpeed = [double]((-2500.0) + (2500.0 * $eased))
            $script:state.gforce = [double](0.5 + (0.5 * $eased))
            $script:state.ias = [double](480.0 - (30.0 * $eased))
            $script:state.agl = 14500.0
            $script:activeEffects = @("Leveling Off", "Stabilizing")
        }
        "spoilers_deploy" {
            # Gradual deploy to full
            $script:state.spoilersPosition = Lerp 0 1 $progress
            $script:state.ias = Lerp 450 400 $progress
            $script:state.agl = 14500
            $script:state.acPitch = 2
            $script:state.acRoll = 0
            $script:state.relativeYaw = 0
            $script:state.yokeX = 0
            $script:state.yokeY = 0
            $script:state.gforce = 1.0
            $script:state.verticalSpeed = 0
            $script:activeEffects = @("Air Brake Deploying", "Air Brake Drag")
        }
        "spoilers_hold" {
            # Hold at full for 5 seconds
            $script:state.spoilersPosition = 1.0
            $script:state.ias = 380
            $script:activeEffects = @("Air Brake Full", "Air Brake Drag")
        }
        "spoilers_retract" {
            # Gradual retract
            $script:state.spoilersPosition = Lerp 1 0 $progress
            $script:state.ias = Lerp 380 420 $progress
            $script:activeEffects = @("Air Brake Retracting", "Engine Vibration")
        }
        "high_g_build" {
            # Gradual G build up using ease function
            $script:state.spoilersPosition = 0
            $easedProgress = EaseInOut $progress
            $script:state.gforce = Lerp 1 4 $easedProgress
            $script:state.acPitch = Lerp 2 25 $easedProgress
            $script:state.acRoll = Lerp 0 30 $easedProgress
            $script:state.engine1AfterburnerRatio = Lerp 0 1 $progress
            $script:state.engine2AfterburnerRatio = Lerp 0 1 $progress
            $script:state.ias = 420
            $script:activeEffects = @("G-Force Building ($([Math]::Round($script:state.gforce, 1))G)", "Afterburner")
        }
        "high_g_peak" {
            # Peak G - hold at 8G
            $easedProgress = EaseInOut $progress
            $script:state.gforce = Lerp 4 8 $easedProgress
            $script:state.acPitch = Lerp 25 50 $easedProgress
            $script:state.acRoll = Lerp 30 70 $easedProgress
            $script:state.engine1AfterburnerRatio = 1.0
            $script:state.engine2AfterburnerRatio = 1.0
            $script:state.ias = 400
            $script:activeEffects = @("G-FORCE PEAK! ($([Math]::Round($script:state.gforce, 1))G)", "Afterburner", "Airframe Stress")
        }
        "high_g_release" {
            # Gradual G release using ease function
            $easedProgress = EaseInOut $progress
            $script:state.gforce = Lerp 8 1.5 $easedProgress
            $script:state.acPitch = Lerp 50 10 $easedProgress
            $script:state.acRoll = Lerp 70 10 $easedProgress
            $script:state.engine1AfterburnerRatio = Lerp 1 0 $progress
            $script:state.engine2AfterburnerRatio = Lerp 1 0 $progress
            $script:activeEffects = @("G-Force Releasing ($([Math]::Round($script:state.gforce, 1))G)", "Engine Vibration")
        }
        "recover" {
            $script:state.gforce = Lerp 1.5 1 $progress
            $script:state.acPitch = Lerp 10 5 $progress
            $script:state.acRoll = Lerp 10 0 $progress
            $script:state.engine1AfterburnerRatio = 0
            $script:state.engine2AfterburnerRatio = 0
            $script:state.engine1Speed = 80
            $script:state.engine2Speed = 80
            $script:activeEffects = @("Recovering", "Engine Vibration")
        }
        "missile_launch" {
            if ($progress -gt 0.3 -and $script:state.missilesCount -eq 4) {
                $script:state.missilesCount = 3
            }
            if ($progress -gt 0.7 -and $script:state.missilesCount -eq 3) {
                $script:state.missilesCount = 2
            }
            $script:state.gforce = 1.0 + (Get-Random -Minimum -5 -Maximum 5) / 100.0
            $script:activeEffects = @("MISSILE LAUNCH!", "Engine Vibration")
        }
        "gun_burst" {
            $burstPhase = ($progress * 8) % 1
            if ($burstPhase -lt 0.4) {
                $newCount = [Math]::Max($script:state.gunShellsCount - 6, 0)
                $script:state.gunShellsCount = $newCount
                $script:state.isCannonFireOn = $true
                $script:state.bodyAccelerationY = (Get-Random -Minimum -25 -Maximum 25) / 100.0
            } else {
                $script:state.isCannonFireOn = $false
            }
            $script:activeEffects = @("GUN FIRING!", "Airframe Vibration")
        }
        "flare_release" {
            $script:state.isCannonFireOn = $false
            if ($progress -gt 0.2 -and $script:state.flareCount -gt 55) {
                $script:state.flareCount -= 1
            }
            if ($progress -gt 0.5 -and $script:state.flareCount -gt 45) {
                $script:state.flareCount -= 1
            }
            if ($progress -gt 0.8 -and $script:state.flareCount -gt 35) {
                $script:state.flareCount -= 1
            }
            $script:activeEffects = @("Flare/Chaff Release", "Engine Vibration")
        }
        "take_damage" {
            $script:state.damage = Lerp 0 0.35 $progress
            $script:state.bodyAccelerationY = (Get-Random -Minimum -35 -Maximum 35) / 100.0
            $script:state.gforce = 1.0 + (Get-Random -Minimum -20 -Maximum 20) / 100.0
            $script:activeEffects = @("TAKING DAMAGE!", "Airframe Vibration")
        }
        "drop_tanks" {
            if ($progress -gt 0.3 -and $script:state.fuelTanksCount -eq 2) {
                $script:state.fuelTanksCount = 1
            }
            if ($progress -gt 0.7 -and $script:state.fuelTanksCount -eq 1) {
                $script:state.fuelTanksCount = 0
            }
            $script:state.bodyAccelerationY = (Get-Random -Minimum -10 -Maximum 10) / 100.0
            $script:activeEffects = @("External Tank Jettison!", "Engine Vibration")
        }
        "turbulence" {
            # Turbulence requires: bodyAccelerationY variability
            # Must be airborne - gear NOT on ground
            $script:state.gearFrontOnGround = $false
            $script:state.gearLeftOnGround = $false
            $script:state.gearRightOnGround = $false
            $script:state.agl = 12000.0
            $script:state.ias = 380.0
            $script:state.groundSpeed = 420.0
            $script:state.verticalSpeed = [double](Get-Random -Minimum -2000 -Maximum 2000)
            # Stronger bodyAccelerationY - this is the key field
            $script:state.bodyAccelerationY = [double]((Get-Random -Minimum -100 -Maximum 100) / 100.0)
            $script:state.gforce = [double](1.0 + ((Get-Random -Minimum -70 -Maximum 70) / 100.0))
            $script:state.acRoll = [double](Get-Random -Minimum -35 -Maximum 35)
            $script:state.acPitch = [double](2.0 + (Get-Random -Minimum -15 -Maximum 15))
            $script:state.windshieldWindVelocity = [double](380.0 + (Get-Random -Minimum -60 -Maximum 60))
            # These MUST be 0 so SimHaptic knows it's turbulence, not pilot input
            $script:state.yokeX = 0.0
            $script:state.yokeY = 0.0
            $script:state.relativeYaw = 0.0
            $script:state.stallPercentage = 0.0
            $script:state.isStalling = $false
            $script:state.engine1Speed = 80.0
            $script:state.engine2Speed = 80.0
            $script:activeEffects = @("HEAVY TURBULENCE!", "bodyAccelY: $([Math]::Round([double]$script:state.bodyAccelerationY, 2))G")
        }
        "stall_approach" {
            # Build up to full stall
            $script:state.ias = Lerp 350 120 $progress
            $script:state.stallPercentage = Lerp 0 1.0 $progress
            $script:state.acPitch = Lerp 5 28 $progress
            $script:state.engine1Speed = 35
            $script:state.engine2Speed = 35
            $script:state.agl = 12000
            $script:state.yokeY = 0
            $script:state.relativeYaw = 0
            if ($progress -gt 0.5) {
                $script:state.acRoll = (Get-Random -Minimum -30 -Maximum 30)
                $script:state.bodyAccelerationY = (Get-Random -Minimum -50 -Maximum 50) / 100.0
            }
            if ($progress -gt 0.8) {
                $script:state.isStalling = $true
            }
            $script:activeEffects = @("STALL BUFFET! ($([Math]::Round([double]$script:state.stallPercentage * 100))%)", "Airframe Shaking")
        }
        "stall_peak" {
            # Hold at 100% stall for 3 seconds
            $script:state.ias = 115
            $script:state.stallPercentage = 1.0
            $script:state.isStalling = $true
            $script:state.acPitch = 30 + (Get-Random -Minimum -5 -Maximum 5)
            $script:state.acRoll = (Get-Random -Minimum -40 -Maximum 40)
            $script:state.bodyAccelerationY = (Get-Random -Minimum -60 -Maximum 60) / 100.0
            $script:state.gforce = 0.8 + (Get-Random -Minimum -20 -Maximum 20) / 100.0
            $script:state.verticalSpeed = -2000 + (Get-Random -Minimum -500 -Maximum 500)
            $script:state.agl = [double](12000 - (1000 * $progress))
            $script:state.yokeY = 0
            $script:state.relativeYaw = 0
            $script:state.engine1Speed = 35
            $script:state.engine2Speed = 35
            $script:activeEffects = @("FULL STALL! 100%", "Wing Drop!", "Airframe Shaking")
        }
        "stall_recovery" {
            $script:state.stallPercentage = Lerp 1.0 0 $progress
            $script:state.ias = Lerp 115 280 $progress
            $script:state.acPitch = Lerp 30 -10 $progress
            $script:state.acRoll = [double]($script:state.acRoll * (1.0 - $progress))
            $script:state.engine1Speed = 95
            $script:state.engine2Speed = 95
            $script:state.isStalling = $progress -lt 0.5
            $script:state.verticalSpeed = Lerp -2500 0 $progress
            $script:state.agl = Lerp 11000 10000 $progress
            $script:state.bodyAccelerationY = 0
            $script:activeEffects = @("Stall Recovery", "Engine Vibration")
        }
        "overspeed_dive" {
            $script:state.ias = Lerp 280 ($script:state.vne + 60) $progress
            $script:state.agl = Lerp 10000 7000 $progress
            $script:state.acPitch = -30
            $script:state.verticalSpeed = -10000
            $script:state.bodyAccelerationY = (Get-Random -Minimum -65 -Maximum 65) / 100.0
            $script:state.gforce = 0.5 + (Get-Random -Minimum -10 -Maximum 10) / 100.0
            $script:activeEffects = @("OVERSPEED! ($([Math]::Round($script:state.ias)) kts)", "Airframe Buffet")
        }
        "approach_setup" {
            $script:state.ias = Lerp ($script:state.vne + 60) 200 $progress
            $script:state.agl = Lerp 7000 2000 $progress
            $script:state.acPitch = Lerp -30 0 $progress
            $script:state.verticalSpeed = -2000
            $script:state.engine1Speed = 70
            $script:state.engine2Speed = 70
            $script:state.gforce = 1.0
            $script:state.surfaceType = "Concrete"
            $script:activeEffects = @("Engine Vibration", "Airframe Airflow")
        }
        "gear_down" {
            $script:state.agl = Lerp 2000 800 $progress
            $script:state.ias = 180
            $script:state.verticalSpeed = -800
            # Gradual gear extension
            $script:state.gearFrontPosition = Lerp 0 1 $progress
            $script:state.gearLeftPosition = Lerp 0 1 $progress
            $script:state.gearRightPosition = Lerp 0 1 $progress
            $script:activeEffects = @("Gear Extending", "Gear Drag", "Engine Vibration")
        }
        "flaps_deploy" {
            $script:state.agl = Lerp 800 500 $progress
            $script:state.ias = 165
            $script:state.verticalSpeed = -600
            $script:state.gearFrontPosition = 1
            $script:state.gearLeftPosition = 1
            $script:state.gearRightPosition = 1
            # Gradual flaps to full
            $script:state.flapsPosition = Lerp 0 1 $progress
            $script:activeEffects = @("Flaps Extending", "Flaps Drag", "Engine Vibration")
        }
        "flaps_hold" {
            $script:state.agl = Lerp 500 350 $progress
            $script:state.flapsPosition = 1.0
            $script:state.ias = 155
            $script:activeEffects = @("Flaps Full", "Gear Drag", "Flaps Drag")
        }
        "hook_down" {
            $script:state.hookPos = Lerp 0 1 $progress
            $script:state.agl = Lerp 350 200 $progress
            $script:state.ias = 150
            $script:activeEffects = @("Hook Extending", "Engine Vibration")
        }
        "final_approach" {
            $script:state.agl = Lerp 200 15 $progress
            $script:state.ias = 145
            $script:state.verticalSpeed = -400
            $script:state.acPitch = -3
            $script:state.groundSpeed = 150
            $script:state.hookPos = 1.0
            $script:state.isFuelPumpOn = $true  # Boost pump on for landing
            $script:activeEffects = @("Final Approach", "Fuel Pump", "Gear Drag", "Flaps Drag")
        }
        "touchdown" {
            $script:state.agl = 0
            $script:state.verticalSpeed = -650
            $script:state.gearFrontOnGround = $true
            $script:state.gearLeftOnGround = $true
            $script:state.gearRightOnGround = $true
            $script:state.surfaceType = "Concrete"
            $script:state.gforce = 1.8
            $script:state.bodyAccelerationY = (Get-Random -Minimum -30 -Maximum 30) / 100.0
            $script:activeEffects = @("TOUCHDOWN!", "Ground Impact")
        }
        "rollout" {
            $script:state.agl = 0
            $script:state.verticalSpeed = 0
            $script:state.groundSpeed = Lerp 150 15 $progress
            $script:state.ias = $script:state.groundSpeed
            $script:state.brakes = 0.85
            $script:state.spoilersPosition = 1.0
            $script:state.gforce = 1.0
            $script:state.bodyAccelerationY = (Get-Random -Minimum -20 -Maximum 20) / 100.0
            $script:activeEffects = @("Ground Roll", "Brakes", "Spoilers", "Ground Bumps")
        }
        "taxi_back" {
            $script:state.groundSpeed = 12 + (Get-Random -Minimum -2 -Maximum 2)
            $script:state.ias = $script:state.groundSpeed
            $script:state.brakes = 0
            $script:state.spoilersPosition = 0
            $script:state.flapsPosition = Lerp 1 0 $progress
            $script:state.hookPos = Lerp 1 0 $progress
            $script:state.engine1Speed = 50
            $script:state.engine2Speed = 50
            $script:state.isFuelPumpOn = $false  # No longer needed
            $script:state.bodyAccelerationY = (Get-Random -Minimum -8 -Maximum 8) / 100.0
            $script:activeEffects = @("Ground Roll", "Ground Bumps", "Engine Vibration")
        }
        "parking" {
            $script:state.groundSpeed = Lerp 12 0 $progress
            $script:state.ias = 0
            $script:state.isParkingBrakeSet = $true
            $script:state.brakes = 1.0
            $script:state.flapsPosition = 0
            $script:state.hookPos = 0
            $script:activeEffects = @("Parking Brake Set", "Brakes")
        }
        "engine_shutdown" {
            $script:state.groundSpeed = 0
            $script:state.brakes = 0
            $script:state.engine1Speed = Lerp 50 0 $progress
            $script:state.engine2Speed = Lerp 50 0 $progress
            if ($progress -gt 0.4) {
                $script:state.engine2Running = $false
            }
            if ($progress -gt 0.7) {
                $script:state.engine1Running = $false
            }
            $script:activeEffects = @("Engine Shutdown", "Engine Vibration (fading)")
        }
        "apu_shutdown" {
            $script:state.engine1Speed = 0
            $script:state.engine2Speed = 0
            $script:state.apu = Lerp 1 0 $progress
            $script:state.doorPos = Lerp 0 1 $progress
            $script:activeEffects = @("APU Shutdown", "Canopy Opening")
        }
        "power_down" {
            $script:state.apu = 0
            $script:state.batteryState = $false
            $script:state.isFuelPumpOn = $false
            $script:state.doorPos = 1.0
            $script:activeEffects = @("(Systems powering down)")
        }
        "complete" {
            $script:activeEffects = @("(Demo complete)")
            if ($progress -ge 1.0) {
                $script:running = $false
                $script:phaseDescription = "Demo Complete - Press SPACE to restart"
            }
        }
    }
    
    if ($script:phaseTime -ge $currentPhaseDef.duration) {
        $script:currentPhaseIndex++
        $script:phaseTime = 0.0
        if ($script:currentPhaseIndex -lt $script:phases.Count) {
            $script:phase = $script:phases[$script:currentPhaseIndex].name
            $script:phaseDescription = $script:phases[$script:currentPhaseIndex].desc
        }
    }
}

function Build-JsonPacket {
    $s = $script:state
    $b = { param($v) if ($v) { "true" } else { "false" } }
    $f = { param($v, $d) [Math]::Round($v, $d) }
    
    $json = '{' +
        '"sh":' + $s.sh + ',' +
        '"aircraftTitle":"' + $s.aircraftTitle + '",' +
        '"acType":"' + $s.acType + '",' +
        '"engineType":"' + $s.engineType + '",' +
        '"surfaceType":"' + $s.surfaceType + '",' +
        '"batteryState":' + (& $b $s.batteryState) + ',' +
        '"hasRetractableGear":' + (& $b $s.hasRetractableGear) + ',' +
        '"isParkingBrakeSet":' + (& $b $s.isParkingBrakeSet) + ',' +
        '"isFuelPumpOn":' + (& $b $s.isFuelPumpOn) + ',' +
        '"canopyJettison":' + (& $b $s.canopyJettison) + ',' +
        '"isCannonFireOn":' + (& $b $s.isCannonFireOn) + ',' +
        '"isStalling":' + (& $b $s.isStalling) + ',' +
        '"isInCockpit":' + (& $b $s.isInCockpit) + ',' +
        '"agl":' + (& $f $s.agl 1) + ',' +
        '"ias":' + (& $f $s.ias 1) + ',' +
        '"groundSpeed":' + (& $f $s.groundSpeed 1) + ',' +
        '"vso":' + (& $f $s.vso 1) + ',' +
        '"vne":' + (& $f $s.vne 1) + ',' +
        '"gforce":' + (& $f $s.gforce 2) + ',' +
        '"verticalSpeed":' + (& $f $s.verticalSpeed 0) + ',' +
        '"stallPercentage":' + (& $f $s.stallPercentage 2) + ',' +
        '"windshieldWindVelocity":' + (& $f $s.windshieldWindVelocity 1) + ',' +
        '"densityAltFt":' + (& $f $s.densityAltFt 0) + ',' +
        '"acPitch":' + (& $f $s.acPitch 1) + ',' +
        '"acRoll":' + (& $f $s.acRoll 1) + ',' +
        '"relativeYaw":' + (& $f $s.relativeYaw 1) + ',' +
        '"accX":' + (& $f $s.accX 2) + ',' +
        '"bodyAccelerationY":' + (& $f $s.bodyAccelerationY 2) + ',' +
        '"gearFrontPosition":' + (& $f $s.gearFrontPosition 2) + ',' +
        '"gearLeftPosition":' + (& $f $s.gearLeftPosition 2) + ',' +
        '"gearRightPosition":' + (& $f $s.gearRightPosition 2) + ',' +
        '"gearFrontOnGround":' + (& $b $s.gearFrontOnGround) + ',' +
        '"gearLeftOnGround":' + (& $b $s.gearLeftOnGround) + ',' +
        '"gearRightOnGround":' + (& $b $s.gearRightOnGround) + ',' +
        '"flapsPosition":' + (& $f $s.flapsPosition 2) + ',' +
        '"spoilersPosition":' + (& $f $s.spoilersPosition 2) + ',' +
        '"brakes":' + (& $f $s.brakes 2) + ',' +
        '"doorPos":' + (& $f $s.doorPos 2) + ',' +
        '"hookPos":' + (& $f $s.hookPos 2) + ',' +
        '"yokeX":' + (& $f $s.yokeX 2) + ',' +
        '"yokeY":' + (& $f $s.yokeY 2) + ',' +
        '"engine1Speed":' + (& $f $s.engine1Speed 1) + ',' +
        '"engine2Speed":' + (& $f $s.engine2Speed 1) + ',' +
        '"engine1Running":' + (& $b $s.engine1Running) + ',' +
        '"engine2Running":' + (& $b $s.engine2Running) + ',' +
        '"engine1StarterOn":' + (& $b $s.engine1StarterOn) + ',' +
        '"engine2StarterOn":' + (& $b $s.engine2StarterOn) + ',' +
        '"engine1AfterburnerRatio":' + (& $f $s.engine1AfterburnerRatio 2) + ',' +
        '"engine2AfterburnerRatio":' + (& $f $s.engine2AfterburnerRatio 2) + ',' +
        '"engine1ReverseThrust":' + (& $f $s.engine1ReverseThrust 2) + ',' +
        '"engine2ReverseThrust":' + (& $f $s.engine2ReverseThrust 2) + ',' +
        '"apu":' + (& $f $s.apu 2) + ',' +
        '"totalWeight":' + (& $f $s.totalWeight 0) + ',' +
        '"maxGrossWeight":' + (& $f $s.maxGrossWeight 0) + ',' +
        '"gunShellsCount":' + $s.gunShellsCount + ',' +
        '"missilesCount":' + $s.missilesCount + ',' +
        '"flareCount":' + $s.flareCount + ',' +
        '"fuelTanksCount":' + $s.fuelTanksCount + ',' +
        '"bombsCount":' + $s.bombsCount + ',' +
        '"damage":' + (& $f $s.damage 2) +
    '}'
    return $json
}

function Send-Packet {
    try {
        $json = Build-JsonPacket
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $null = $udpClient.Send($bytes, $bytes.Length, $endpoint)
        $script:packetsSent++
    } catch { }
}

function Format-Time($seconds) {
    $mins = [int][Math]::Floor($seconds / 60)
    $secs = [int][Math]::Floor($seconds % 60)
    return "{0}:{1:D2}" -f $mins, $secs
}

function Get-TotalDuration {
    $total = 0
    foreach ($p in $script:phases) { $total += $p.duration }
    return $total
}

function Update-Display {
    Clear-Host
    $s = $script:state
    $totalDuration = Get-TotalDuration
    
    Write-Host ""
    Write-Host "  ======================================================================" -ForegroundColor Cyan
    Write-Host "           SIMHAPTIC FULL DEMO - AUTOMATED FLIGHT SEQUENCE" -ForegroundColor Yellow
    Write-Host "  ======================================================================" -ForegroundColor Cyan
    Write-Host ""
    
    $statusColor = if ($script:running) { "Green" } else { "Yellow" }
    $statusText = if ($script:running) { "RUNNING" } else { "STOPPED" }
    Write-Host "  Status: " -NoNewline
    Write-Host "$statusText" -ForegroundColor $statusColor -NoNewline
    Write-Host "    Time: $(Format-Time $script:totalTime) / $(Format-Time $totalDuration)" -NoNewline
    Write-Host "    Packets: $script:packetsSent" -ForegroundColor Gray
    Write-Host ""
    
    $progressPct = if ($totalDuration -gt 0) { $script:totalTime / $totalDuration } else { 0 }
    $barWidth = 60
    $filledWidth = [Math]::Floor($progressPct * $barWidth)
    $emptyWidth = $barWidth - $filledWidth
    $bar1 = "=" * $filledWidth
    $bar2 = "-" * $emptyWidth
    Write-Host "  [$bar1" -NoNewline -ForegroundColor Green
    Write-Host "$bar2] $([Math]::Floor($progressPct * 100))%" -ForegroundColor DarkGray
    Write-Host ""
    
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host "  PHASE: " -NoNewline
    $phaseColor = "White"
    if ($script:phase -match "catapult|high_g|damage") { $phaseColor = "Red" }
    elseif ($script:phase -match "stall|overspeed") { $phaseColor = "Yellow" }
    elseif ($script:phase -match "gun|missile") { $phaseColor = "Magenta" }
    elseif ($script:phase -match "touchdown") { $phaseColor = "Green" }
    Write-Host "$($script:phaseDescription)" -ForegroundColor $phaseColor
    Write-Host "  ----------------------------------------------------------------------" -ForegroundColor DarkCyan
    Write-Host ""
    
    Write-Host "  ACTIVE EFFECTS:" -ForegroundColor Magenta
    if ($script:activeEffects.Count -gt 0) {
        foreach ($effect in $script:activeEffects) {
            $effectColor = "Cyan"
            if ($effect -match "CATAPULT|G-FORCE|8G|DAMAGE|PEAK") { $effectColor = "Red" }
            elseif ($effect -match "STALL|OVERSPEED|TURBULENCE") { $effectColor = "Yellow" }
            elseif ($effect -match "GUN|MISSILE") { $effectColor = "Magenta" }
            elseif ($effect -match "TOUCHDOWN") { $effectColor = "Green" }
            Write-Host "    * $effect" -ForegroundColor $effectColor
        }
    } else {
        Write-Host "    (none)" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    Write-Host "  TELEMETRY:" -ForegroundColor Blue
    $onGround = $s.gearFrontOnGround -or $s.gearLeftOnGround -or $s.gearRightOnGround
    $flightState = if ($onGround) { "GROUND" } else { "FLIGHT" }
    $flightColor = if ($onGround) { "Yellow" } else { "Cyan" }
    Write-Host "    State: " -NoNewline
    Write-Host "$flightState" -ForegroundColor $flightColor -NoNewline
    Write-Host "  AGL: $([Math]::Round($s.agl, 0)) ft  IAS: $([Math]::Round($s.ias, 0)) kts  V/S: $([Math]::Round($s.verticalSpeed, 0)) fpm"
    
    $gColor = if ([Math]::Abs([double]$s.gforce) -gt 5) { "Red" } elseif ([Math]::Abs([double]$s.gforce) -gt 3) { "Yellow" } else { "White" }
    Write-Host "    G-Force: " -NoNewline
    Write-Host "$([Math]::Round([double]$s.gforce, 1)) G" -ForegroundColor $gColor -NoNewline
    Write-Host "  accX: $([Math]::Round([double]$s.accX, 1)) G" -NoNewline
    [double]$bodyYVal = $s.bodyAccelerationY
    $bodyYColor = if ([Math]::Abs($bodyYVal) -gt 0.3) { "Yellow" } else { "White" }
    Write-Host "  bodyY: " -NoNewline
    Write-Host "$([Math]::Round($bodyYVal, 2)) G" -ForegroundColor $bodyYColor
    Write-Host "    Pitch: $([Math]::Round([double]$s.acPitch, 0)) deg  Roll: $([Math]::Round([double]$s.acRoll, 0)) deg  Yaw: $([Math]::Round([double]$s.relativeYaw, 0)) deg"
    Write-Host "    Stall: $([Math]::Round([double]$s.stallPercentage * 100, 0))%  Dmg: $([Math]::Round([double]$s.damage * 100, 0))%  Yoke: X=$([Math]::Round([double]$s.yokeX, 1)) Y=$([Math]::Round([double]$s.yokeY, 1))"
    Write-Host ""
    
    Write-Host "  SYSTEMS:" -ForegroundColor DarkYellow
    $eng1Color = if ($s.engine1Running) { "Green" } else { "Red" }
    $eng2Color = if ($s.engine2Running) { "Green" } else { "Red" }
    Write-Host "    ENG1: " -NoNewline
    Write-Host "$([Math]::Round($s.engine1Speed, 0))%" -ForegroundColor $eng1Color -NoNewline
    Write-Host "  ENG2: " -NoNewline
    Write-Host "$([Math]::Round($s.engine2Speed, 0))%" -ForegroundColor $eng2Color -NoNewline
    $abPct = [Math]::Round($s.engine1AfterburnerRatio * 100, 0)
    $abColor = if ($abPct -gt 0) { "Red" } else { "DarkGray" }
    Write-Host "  A/B: " -NoNewline
    Write-Host "$abPct%" -ForegroundColor $abColor -NoNewline
    Write-Host "  APU: $([Math]::Round($s.apu * 100, 0))%"
    
    $gearPct = [Math]::Round($s.gearFrontPosition * 100, 0)
    Write-Host "    Gear: $gearPct%  Flaps: $([Math]::Round($s.flapsPosition * 100, 0))%  Spoilers: $([Math]::Round($s.spoilersPosition * 100, 0))%  Hook: $([Math]::Round($s.hookPos * 100, 0))%"
    $fpColor = if ($s.isFuelPumpOn) { "Cyan" } else { "DarkGray" }
    $fpStatus = if ($s.isFuelPumpOn) { "ON" } else { "OFF" }
    Write-Host "    Fuel Pump: " -NoNewline
    Write-Host "$fpStatus" -ForegroundColor $fpColor -NoNewline
    Write-Host "  Battery: $(if ($s.batteryState) { 'ON' } else { 'OFF' })"
    Write-Host ""
    
    Write-Host "  STORES:" -ForegroundColor Red
    Write-Host "    Guns: $($s.gunShellsCount)  Missiles: $($s.missilesCount)  Flares: $($s.flareCount)  Tanks: $($s.fuelTanksCount)"
    Write-Host ""
    
    Write-Host "  ======================================================================" -ForegroundColor White
    if ($script:running) {
        Write-Host "              Press [SPACE] to RESET    [Q] to QUIT" -ForegroundColor Yellow
    } else {
        Write-Host "              Press [SPACE] to START    [Q] to QUIT" -ForegroundColor Green
    }
    Write-Host "  ======================================================================" -ForegroundColor White
}

# Main Loop
$appRunning = $true
$lastUpdate = Get-Date
$displayCounter = 0
$dt = 1.0 / $updateRate

Reset-State
Update-Display

while ($appRunning) {
    $now = Get-Date
    $elapsed = ($now - $lastUpdate).TotalMilliseconds
    
    if ($elapsed -ge (1000 / $updateRate)) {
        $lastUpdate = $now
        
        if ($script:running) {
            Update-Phase $dt
        }
        
        Send-Packet
        
        $displayCounter++
        if ($displayCounter -ge ($updateRate / 3)) {
            $displayCounter = 0
            Update-Display
        }
    }
    
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Spacebar') {
            if ($script:running) {
                Reset-State
            } else {
                Start-Demo
            }
            Update-Display
        }
        elseif ($key.Key -eq 'Q') {
            $appRunning = $false
        }
    }
    
    Start-Sleep -Milliseconds 5
}

$udpClient.Close()
Write-Host ""
Write-Host "Demo stopped. Sent $script:packetsSent packets." -ForegroundColor Yellow
