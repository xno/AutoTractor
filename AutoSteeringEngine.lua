AutoSteeringEngine = {}

ASECurrentModDir = g_currentModDirectory
ASEModsDirectory = g_modsDirectory.."/"

function AutoSteeringEngine.globalsReset( createIfMissing )

	ASEGlobals = {};
	ASEGlobals.chainMax     = 0
	ASEGlobals.chainMinLen  = 0
	ASEGlobals.chainLen     = 0
	ASEGlobals.chainLenInc  = 0
	ASEGlobals.chainRefine  = 0
	ASEGlobals.chainDivide  = 0
	ASEGlobals.chainFactor1 = 0
	ASEGlobals.widthDec     = 0
	ASEGlobals.angleMax     = 0
	ASEGlobals.angleStep    = 0
	ASEGlobals.angleSafety  = 0
	ASEGlobals.maxLooking   = 0
	ASEGlobals.aiSteering   = 0
	ASEGlobals.aiSteering2  = 0
	ASEGlobals.aiSteering3  = 0
  ASEGlobals.average      = 0
  ASEGlobals.offtracking  = 0
  ASEGlobals.reverseDir   = 0
	ASEGlobals.minMidDist   = 0
	ASEGlobals.showTrace    = 0
	ASEGlobals.minLength    = 0
	ASEGlobals.roueSupport  = 0
	ASEGlobals.artAxisMode  = 0
	ASEGlobals.artAxisRot   = 0
	ASEGlobals.artAxisShift = 0
	ASEGlobals.showChannels = 0
	ASEGlobals.stepLog2     = 0
	ASEGlobals.yieldCount   = 0
	ASEGlobals.zeroAngle    = 0
	ASEGlobals.colliMask    = 0
	ASEGlobals.ignoreDist   = 0
	ASEGlobals.colliStep    = 0
	ASEGlobals.getIsHired   = 0
	
	local file
	file = ASECurrentModDir.."autoSteeringEngineConfig.xml"
	if fileExists(file) then	
		AutoSteeringEngine.globalsLoad( file )	
	else
		print("ERROR: NO GLOBALS IN "..file)
	end
	
	file = ASEModsDirectory.."autoSteeringEngineConfig.xml"
	if fileExists(file) then	
		AutoSteeringEngine.globalsLoad( file )	
	elseif createIfMissing then
		AutoSteeringEngine.globalsCreate()
	end
	
	print("AutoSteeringEngine initialized");
end
	
function AutoSteeringEngine.globalsLoad( file )	

	local xmlFile = loadXMLFile( "ASE", file, "ASEGlobals" )
	for name,value in pairs(ASEGlobals) do
		local tp = Utils.getNoNil( getXMLString(xmlFile, "ASEGlobals." .. name .. "#type"), "int" )
		if     tp == "bool" then
			local bool = getXMLBool( xmlFile, "ASEGlobals." .. name .. "#value" )
			if bool ~= nil then
				if bool then ASEGlobals[name] = 1 else ASEGlobals[name] = 0 end
			end
			--print(file..": "..name.." = "..ASEGlobals[name])
		elseif tp == "float" then
			local float = getXMLFloat( xmlFile, "ASEGlobals." .. name .. "#value" )
			if float ~= nil then ASEGlobals[name] = float end
			--print(file..": "..name.." = "..ASEGlobals[name])
		elseif tp == "int" then
			local int = getXMLInt( xmlFile, "ASEGlobals." .. name .. "#value" )
			if int ~= nil then ASEGlobals[name] = int end
			--print(file..": "..name.." = "..ASEGlobals[name])
		else
			print(file..": "..name..": invalid XML type : "..tp)
		end
	end
end

function AutoSteeringEngine.globalsCreate()	

	local file = g_modsDirectory.."/autoSteeringEngineConfig.xml"

	local xmlFile = createXMLFile( "ASE", file, "ASEGlobals" )
	for name,value in pairs(ASEGlobals) do
		if     value == 0 then
			setXMLString( xmlFile, "ASEGlobals." .. name .. "#type", "bool" )
			setXMLBool( xmlFile, "ASEGlobals." .. name .. "#value", false )
		elseif value == 1 then
			setXMLString( xmlFile, "ASEGlobals." .. name .. "#type", "bool" )
			setXMLBool( xmlFile, "ASEGlobals." .. name .. "#value", true )
		elseif math.abs( value - math.floor( value ) ) > 1E-6 then
			setXMLString( xmlFile, "ASEGlobals." .. name .. "#type", "float" )
			setXMLFloat( xmlFile, "ASEGlobals." .. name .. "#value", value )
		else 
			setXMLInt( xmlFile, "ASEGlobals." .. name .. "#value", value )
		end
	end
	
	saveXMLFile(xmlFile)	
end
	

AutoSteeringEngine.resetCounter = 0;
AutoSteeringEngine.globalsReset( false );

ASEStatus = {}
ASEStatus.initial  = 0;
ASEStatus.steering = 1;
ASEStatus.rotation = 2;
ASEStatus.position = 3;


------------------------------------------------------------------------
-- checkChain
------------------------------------------------------------------------
function AutoSteeringEngine.checkChain( vehicle, iRefNode, zOffset, wheelBase, maxSteering, widthOffset, turnOffset, isInverted, useFrontPacker )

	local resetTools = false

	AutoSteeringEngine.currentSteeringAngle( vehicle, isInverted );

	if     vehicle.aseChain == nil
			or vehicle.aseChain.resetCounter == nil
			or vehicle.aseChain.resetCounter < AutoSteeringEngine.resetCounter then
		AutoSteeringEngine.initChain( vehicle, iRefNode, zOffset, wheelBase, maxSteering, widthOffset, turnOffset );
	else
		vehicle.aseChain.wheelBase   = wheelBase;
		vehicle.aseChain.invWheelBase = 1 / wheelBase;
		vehicle.aseChain.maxSteering = maxSteering;
		if vehicle.aseChain.zOffset ~= zOffset then
			vehicle.aseChain.zOffset   = zOffset;
			setTranslation( vehicle.aseChain.refNode, 0,0, vehicle.aseChain.zOffset );
		end
	end	

	if vehicle.aseChain.useFrontPacker ~= nil and vehicle.aseChain.useFrontPacker ~= useFrontPacker then
		resetTools = true
	end

	if maxSteering ~= nil and 1E-4 < maxSteering and maxSteering < 0.5 * math.pi then
		vehicle.aseChain.radius    = wheelBase / math.tan( maxSteering )
	else
		vehicle.aseChain.radius    = 5
	end
	
	vehicle.aseChain.isInverted	    = isInverted
	vehicle.aseChain.useFrontPacker = useFrontPacker 
	
	AutoSteeringEngine.checkTools( vehicle, resetTools );
	
end

------------------------------------------------------------------------
-- getWidthOffset
------------------------------------------------------------------------
function AutoSteeringEngine.getWidthOffset( vehicle, width, widthOffset )
	local scale  = Utils.getNoNil( vehicle.aiTurnWidthScale, 0.9 )
	local diff   = Utils.getNoNil( vehicle.aiTurnWidthMaxDifference, 0.5 )
	local offset = 0.5 * ( width - math.max(width * scale, width - diff) )
	if widthOffset ~= nil then
		offset = offset - widthOffset
	end
	return offset
end

------------------------------------------------------------------------
-- addToolsRec
------------------------------------------------------------------------
function AutoSteeringEngine.addToolsRec( vehicle, obj )
	if obj ~= nil and obj.attachedImplements ~= nil then
		for _, implement in pairs(obj.attachedImplements) do
			if      implement.object                    ~= nil 
					and implement.object.attacherJoint      ~= nil 
					and implement.object.attacherJoint.node ~= nil then					
				local iCultivator = AutoSteeringEngine.addTool(vehicle,implement.object,implement.object.attacherJoint.node)
				if      vehicle.aseChain.useFrontPacker
						and iCultivator > 0
						and SpecializationUtil.hasSpecialization(Cultivator, implement.object.specializations) then
					vehicle.aseTools[iCultivator].aiTerrainDetailChannel1 = g_currentMission.ploughChannel
					vehicle.aseTools[iCultivator].aiTerrainDetailChannel2 = -1
					vehicle.aseTools[iCultivator].aiTerrainDetailChannel3 = -1
					AutoSteeringEngine.registerFrontPacker( implement.object )
				end
				AutoSteeringEngine.addToolsRec( vehicle, implement.object )
			end
		end	
	end
end

------------------------------------------------------------------------
-- checkTools
------------------------------------------------------------------------
function AutoSteeringEngine.checkTools( vehicle, reset )
	
	if vehicle.aseChain ~= nil and ( vehicle.aseTools == nil or reset ) then
		AutoSteeringEngine.resetFrontPacker( vehicle )
		AutoSteeringEngine.deleteTools( vehicle )
		vehicle.aseTools = nil
		vehicle.aseCollisions = nil
		
		AutoSteeringEngine.addToolsRec( vehicle, vehicle )
		
		if vehicle.aseTools == nil then
			AutoSteeringEngine.addTool(vehicle,vehicle,vehicle.aseChain.refNode);
		end
		
		if vehicle.aseTools == nil then
			vehicle.aseTools = {};
		end
	end

	local dx,dz,zb = 0,0,0;
	
	if AutoSteeringEngine.hasTools( vehicle ) then
		dz = -99
		zb =  99
		for i=1,table.getn( vehicle.aseTools ) do
			local _,_,zDist   = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, vehicle.aseTools[i].refNode );
			
			local dx1 = vehicle.aseTools[i].xl-vehicle.aseTools[i].xr
			local dz1 = vehicle.aseTools[i].z  + zDist
			local zb1 = vehicle.aseTools[i].zb + zDist
			if vehicle.aseTools[i].isSprayer and zb1 < dz1 then
				zb1 = dz1 -1
			end
			
			if dx < dx1 then dx = dx1 end
			if dz < dz1 then dz = dz1 end
			if zb > zb1 then zb = zb1 end
			
    end
		local wo = AutoSteeringEngine.getWidthOffset( vehicle, dx )
		dx = 0.5 * dx - wo
	end
	
	return dx,dz,zb;
end

------------------------------------------------------------------------
-- hasTools
------------------------------------------------------------------------
function AutoSteeringEngine.hasTools( vehicle )
	if vehicle.aseChain == nil or vehicle.aseLRSwitch == nil or vehicle.aseTools == nil or table.getn( vehicle.aseTools ) < 1 then
		return false;
	end
	return true;
end

function AutoSteeringEngine.enableCheckTurnPoint( vehicle )
	if      vehicle.aseDirectionBeforeTurn   ~= nil
			and vehicle.aseDirectionBeforeTurn.x ~= nil
			and vehicle.aseDirectionBeforeTurn.z ~= nil then
		vehicle.aseCheckTurnPoint = true;
	end
end

------------------------------------------------------------------------
-- initTools
------------------------------------------------------------------------
function AutoSteeringEngine.initTools( vehicle, maxLooking, leftActive, widthOffset, headlandDist, collisionDist, turnMode, savedMarker, uTurn )

	if     vehicle.aseLRSwitch == nil or vehicle.aseLRSwitch ~= leftActive
			or vehicle.aseHeadland == nil or vehicle.aseHeadland ~= headlandDist then
		AutoSteeringEngine.setChainStatus( vehicle, 1, ASEStatus.initial );
	end
	
	vehicle.aseCheckTurnPoint = false;
	vehicle.aseLRSwitch    = leftActive;
	vehicle.aseHeadland    = headlandDist;
	vehicle.aseTurnMode    = turnMode
	if collisionDist > 1 then
		vehicle.aseCollision = collisionDist 
	else
		vehicle.aseCollision =  0
	end
	vehicle.aseToolParams  = {};
		
	if AutoSteeringEngine.hasTools( vehicle ) then	
		local x = {}
		for i=1,table.getn( vehicle.aseTools ) do
		
			local skip = false
			for j=1,table.getn( vehicle.aseTools ) do
				if i ~= j then
					if     ( vehicle.aseTools[i].isCombine 
								or vehicle.aseTools[i].isPlough 
								or vehicle.aseTools[i].isSprayer 
								or vehicle.aseTools[i].isMower
								or vehicle.aseTools[i].outTerrainDetailChannel >= 0
								--or ( vehicle.aseTools[i].specialType ~= nil and vehicle.aseTools[i].specialType ~= "" ) 
								 )
							and vehicle.aseTools[i].isCombine   == vehicle.aseTools[j].isCombine  
							and vehicle.aseTools[i].isPlough    == vehicle.aseTools[j].isPlough   
							and vehicle.aseTools[i].isSprayer   == vehicle.aseTools[j].isSprayer  
							and vehicle.aseTools[i].isMower     == vehicle.aseTools[j].isMower
							and vehicle.aseTools[i].outTerrainDetailChannel == vehicle.aseTools[j].outTerrainDetailChannel 
							--and vehicle.aseTools[i].specialType == vehicle.aseTools[j].specialType
							then
						
						if x[j] == nil then	
							local tool = vehicle.aseTools[j]
							local xOffset,_,_ = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode, tool.refNode );
							for m=1,table.getn(tool.marker) do
								local xxx,_,_ = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode, tool.marker[m] );
								xxx = xxx - xOffset;
								if tool.invert then xxx = -xxx end
								if x[j] == nil then
									x[j] = xxx
								elseif vehicle.aseLRSwitch then
									if x[j] < xxx then x[j] = xxx end
								else
									if x[j] > xxx then x[j] = xxx end
								end
							end
							local xxx = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, tool.refNode );
							x[j]  = x[j] + xxx
						end
						
						if x[i] == nil then
							tool = vehicle.aseTools[i]
							xOffset,_,_ = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode, tool.refNode );
							for m=1,table.getn(tool.marker) do
								local xxx,_,_ = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode, tool.marker[m] );
								xxx = xxx - xOffset;
								if tool.invert then xxx = -xxx end
								if x[i] == nil then
									x[i] = xxx
								elseif vehicle.aseLRSwitch then
									if x[i] < xxx then x[i] = xxx end
								else
									if x[i] > xxx then x[i] = xxx end
								end
							end
							xxx = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, tool.refNode );
							x[i]  = x[i] + xxx
						end
						
						if vehicle.aseLRSwitch then
							skip = ( x[i] + 0.2 < x[j] )
						else
							skip = ( x[i] - 0.2 > x[j] )
						end
						
						--if skip then
						--	print("x[i]: "..tostring(x[i]).." x[j]: "..tostring(x[j]).." "..tostring(vehicle.aseLRSwitch))
						--end
					end
				end
			end
			
			local tp = AutoSteeringEngine.getSteeringParameterOfTool( vehicle, i, maxLooking, widthOffset )
			tp.skip = skip
			vehicle.aseToolParams[i] = tp
		end
	end
	
	AutoSteeringEngine.initSteering( vehicle, savedMarker, uTurn );
end

------------------------------------------------------------------------
-- AutoSteeringEngineCallback
------------------------------------------------------------------------
AutoSteeringEngineCallback = {}
function AutoSteeringEngineCallback.create( vehicle )
	local self = {}
	self.vehicle = vehicle
	self.raycast = AutoSteeringEngineCallback.raycast
	self.overlap = AutoSteeringEngineCallback.overlap
	return self
end

------------------------------------------------------------------------
-- AutoSteeringEngineCallback:raycast
------------------------------------------------------------------------
function AutoSteeringEngineCallback:raycast( transformId, x, y, z, distance )
	
	if transformId == g_currentMission.terrainRootNode then
		return true
	end

	local other  = nil
	local nodeId = transformId
	repeat
		other  = g_currentMission.nodeToVehicle[nodeId]
		if other == nil then
			nodeId = getParent( nodeId )	
		end
	until other ~= nil or nodeId == nil or nodeId == 0
	
	if     other == nil then
	--	print("static  "..tostring(getName(transformId)).." @ x: "..tostring(x).." z: "..tostring(z))
		self.vehicle.aseHasCollision = true

		if ASECollisionPoints == nil then
			ASECollisionPoints = {}
		end
		local p = {}
		p.x = x
		p.y = y 
		p.z = z
		table.insert( ASECollisionPoints, p )
		
		return false
		
	elseif not( other == self.vehicle
					 or self.vehicle.trafficCollisionIgnoreList[transformId]
					 or self.vehicle.trafficCollisionIgnoreList[parent]
					 or self.vehicle.trafficCollisionIgnoreList[parentParent]
					 or AutoSteeringEngine.isAttachedImplement( self.vehicle, object ) ) then
	--	print("vehicle  "..tostring(getName(transformId)))
	--	self.vehicle.aseHasCollision = true
	--	return false
	end

	return true	
end


------------------------------------------------------------------------
-- AutoSteeringEngineCallback:overlap
------------------------------------------------------------------------
function AutoSteeringEngineCallback:overlap( transformId )

	local parent = getParent(transformId)
	
	if     transformId         == g_currentMission.terrainRootNode 
			or parent              == g_currentMission.terrainRootNode then
		return true
	end

	local parentParent = getParent(parent)	
	local other = g_currentMission.nodeToVehicle[transformId]
	if other == nil then
		other = g_currentMission.nodeToVehicle[parent]
	end
	if other == nil then
		other = g_currentMission.nodeToVehicle[parentParent]
	end			
	
	if     other == nil 
			or not( other == self.vehicle
					 or self.vehicle.trafficCollisionIgnoreList[transformId]
					 or self.vehicle.trafficCollisionIgnoreList[parent]
					 or self.vehicle.trafficCollisionIgnoreList[parentParent]
					 or AutoSteeringEngine.isAttachedImplement( self.vehicle, object ) ) then
		self.vehicle.aseHasCollision = true
		return false
	end

	return true	
end


------------------------------------------------------------------------
-- hasCollisionHelper
------------------------------------------------------------------------
function AutoSteeringEngine.hasCollisionHelper( vehicle, wx, wz, dx, dz, l, doBreak )
	if boBreak and vehicle.aseHasCollision then
		return
	end
	
	if     not AutoSteeringEngine.checkField( vehicle, wx + l * dx, wz + l * dz )
			or not AutoSteeringEngine.checkField( vehicle, wx , wz )then										
		local wy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wx, 1, wz) 
		local dy = ( getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wx + l * dx, 1, wz + l * dz) - wy ) / l
		local hasCollision = vehicle.aseHasCollision
		vehicle.aseHasCollision = false
		for y=0.5,1.5,ASEGlobals.colliStep do					
			if vehicle.aseHasCollision then
				break
			end
			raycastAll(wx, wy + y, wz, dx, dy, dz, "raycast", l, vehicle.aseCallback )--, nil, ASEGlobals.colliMask )
		end
		if hasCollision then
			vehicle.aseHasCollision = true
		end
	end
end

------------------------------------------------------------------------
-- hasCollision
------------------------------------------------------------------------
function AutoSteeringEngine.hasCollision( vehicle, nodeId )
	if vehicle.aseCollision < 1 then return false end
	if ASEGlobals.colliMask <= 0 then return false end
	if vehicle.aseChain == nil or vehicle.aseChain.headlandNode == nil then return false end
	if nodeId == nil then nodeId = vehicle.aseChain.headlandNode end
	
	if vehicle.aseCollisions == nil then
		vehicle.aseCollisions = {}
	end
	
	if vehicle.aseCollisions[nodeId] == nil then
		if vehicle.aseCallback == nil then
			vehicle.aseCallback = AutoSteeringEngineCallback.create( vehicle )
		end
		vehicle.aseHasCollision = false
	
		if     not AutoSteeringEngine.isFieldAhead( vehicle,  vehicle.aseCollision, nodeId )
				or not AutoSteeringEngine.isFieldAhead( vehicle, -vehicle.aseCollision, nodeId ) then
			local r0 = 1.5
			if vehicle.aseChain.radius ~= nil then
				r0 = math.max( r0, vehicle.aseChain.radius )
			end
			local sut, rev = AutoSteeringEngine.getTurnMode( vehicle )
			if     vehicle.aseTurnMode == "A"
					or vehicle.aseTurnMode == "L" then
				r0 = r0 + math.max( 3, Utils.getNoNil( vehicle.aseChain.wheelBase, 0 ) + 2 )
			end
			if AutoSteeringEngine.hasTools( vehicle ) then
				for _,tool in pairs(vehicle.aseTools) do
					r0 = math.max( r0, math.max( tool.xl, tool.xr ) )
				end
			end
			
			local wx, wy, wz = getWorldTranslation( nodeId )
			
			local cx1, cx2, cz1, cz2
			
			if ASECollisionPoints ~= nil and table.getn( ASECollisionPoints ) > 0 then
				local cl = Utils.vector2LengthSq( r0, vehicle.aseCollision )
			
				for _,p in pairs( ASECollisionPoints ) do
					--print("x: "..tostring(wx).." z: "..tostring(wz).." p.x: "..tostring(p.x).." p.z: "..tostring(p.z))
					if Utils.vector2LengthSq( wx - p.x, wz - p.z ) <= cl then
						local lx, ly, lz = worldToLocal( nodeId, wx, wy, wz )
						local ax
						if     lx > 1.5 then
							ax = lx							
						elseif lx < -1.5 then
							ax = -lx
						else
							ax = 0
						end						
						local az = math.abs( lz )
						--print("ax: "..tostring(ax).." az: "..tostring(az))
						if ax < 1 and az < 1 then
							--print("found static 1")
							vehicle.aseHasCollision = true
							break
						elseif  az <= vehicle.aseCollision 
						    and ( ax < 1E-3 or ax <= az * r0 / vehicle.aseCollision ) then
							--print("found static 2")
							vehicle.aseHasCollision = true
							break
						end
					end
				end
			end
			
			if not vehicle.aseHasCollision then
				--local maxCl = Utils.vector2Length( r0 + 1.5, vehicle.aseCollision )
				-- left & right
				for f=0,1,ASEGlobals.colliStep do
					local r          = f * r0 
					local cl         = math.sqrt( r * r + vehicle.aseCollision * vehicle.aseCollision )
					cx1,_,cz1  = localDirectionToWorld( vehicle.aseChain.headlandNode, r / cl, 0, vehicle.aseCollision / cl )
					cx2,_,cz2  = localDirectionToWorld( vehicle.aseChain.headlandNode,-r / cl, 0, vehicle.aseCollision / cl )
					--cl = math.min( cl, maxCl )
													
					AutoSteeringEngine.hasCollisionHelper( vehicle, wx, wz, cx1, cz1, cl )
					AutoSteeringEngine.hasCollisionHelper( vehicle, wx, wz,-cx1,-cz1, cl )
					AutoSteeringEngine.hasCollisionHelper( vehicle, wx, wz, cx2, cz2, cl )
					AutoSteeringEngine.hasCollisionHelper( vehicle, wx, wz,-cx2,-cz2, cl )					
				end

				-- the T (front & back)
				cx1,_,cz1  = localDirectionToWorld( vehicle.aseChain.headlandNode, 1, 0, 0 )
				cx2,_,cz2  = localDirectionToWorld( vehicle.aseChain.headlandNode, 0, 0, 1 )
				for z=-3,0,ASEGlobals.colliStep do
					local vx, vz
					vx = wx + ( z + vehicle.aseCollision ) * cx2 - r0 * cx1
					vz = wz + ( z + vehicle.aseCollision ) * cz2 - r0 * cz1 					
					AutoSteeringEngine.hasCollisionHelper( vehicle, vx, vz, cx1, cz1, r0 + r0 )
					vx = wx - ( z + vehicle.aseCollision ) * cx2 - r0 * cx1                   
					vz = wz - ( z + vehicle.aseCollision ) * cz2 - r0 * cz1                   
					AutoSteeringEngine.hasCollisionHelper( vehicle, vx, vz, cx1, cz1, r0 + r0 )
				end
				
				-- the middle (vehicle width)
				for x=-1.5,1.5,ASEGlobals.colliStep do
					vx = wx + x * cx1
					vz = wz + x * cz1 																
					AutoSteeringEngine.hasCollisionHelper( vehicle, vx, vz, cx2, cz2, vehicle.aseCollision )
					AutoSteeringEngine.hasCollisionHelper( vehicle, vx, vz,-cx2,-cz2, vehicle.aseCollision )
				end
			end
		end
		
		vehicle.aseCollisions[nodeId] = vehicle.aseHasCollision
	end
	
	return vehicle.aseCollisions[nodeId]
end

------------------------------------------------------------------------
-- isAttachedImplement
------------------------------------------------------------------------
function AutoSteeringEngine.isAttachedImplement( vehicle, object )
	if vehicle == nil or object == nil then
		return false
	end
	if vehicle == object then
		return true
	end
	if vehicle.attachedImplements == nil then
		return false
	end	
	for _, implement in pairs(vehicle.attachedImplements) do
		if AutoSteeringEngine.isAttachedImplement( implement.object, object ) then
			return true
		end
	end		
	return false
end

------------------------------------------------------------------------
-- hasFruits
------------------------------------------------------------------------
function AutoSteeringEngine.hasFruits( vehicle, widthFactor )

	if not vehicle.isServer then return false end
	
	if AutoSteeringEngine.hasCollision( vehicle ) then return false end

	if widthFactor == nil then widthFactor = 1 end
	
	local fruitsDetected = false;
	
	if  AutoSteeringEngine.hasTools( vehicle ) and vehicle.aseToolParams ~= nil and table.getn( vehicle.aseToolParams ) == table.getn( vehicle.aseTools ) then
		for i = 1,table.getn( vehicle.aseToolParams ) do	
			local tool      = vehicle.aseTools[vehicle.aseToolParams[i].i]
			local gotFruits = false
			local back      = vehicle.aseToolParams[i].zReal + math.min( vehicle.aseToolParams[i].zBack - vehicle.aseToolParams[i].zReal -1, -1 )
			local front     = vehicle.aseToolParams[i].zReal + math.max( vehicle.aseToolParams[i].zBack - vehicle.aseToolParams[i].zReal +1,  1 )
			local dx,dz
			if tool.steeringAxleNode == nil then
				dx,_,dz = localDirectionToWorld( vehicle.aseChain.refNode, 0, 0, 1 )
			elseif tool.invert then
				dx,_,dz = localDirectionToWorld( tool.steeringAxleNode, 0, 0, -1 )
			else
				dx,_,dz = localDirectionToWorld( tool.steeringAxleNode, 0, 0, 1 )
			end
			
			local cx,cz = AutoSteeringEngine.getChainPoint( vehicle, 1, vehicle.aseToolParams[i] );
			local xw2,y,zw2 = localToWorld( vehicle.aseChain.nodes[1].index, cx, 0, cz - vehicle.aseToolParams[i].z + front );

			local xw1 = xw2 + ( back - front ) * dx
			local zw1 = zw2 + ( back - front ) * dz
			
			local w = widthFactor * vehicle.aseToolParams[i].width;
			if vehicle.aseLRSwitch then
				w = -w;
			end
			
			local lx1,lz1,lx2,lz2,lx3,lz3,lx4,lz4
			dist = front - back
			repeat 
				xw2 = xw1 + dist * dx
				zw2 = zw1 + dist * dz
				lx1,lz1,lx2,lz2,lx3,lz3 = AutoSteeringEngine.getParallelogram( xw1,zw1,xw2,zw2, w, true )
				lx4 = lx3 + lx2 - lx1
				lz4 = lz3 + lz2 - lz1
				
				dist = dist - 0.5
			until dist < 0.5
					or ( vehicle.aseHeadland >= 1
					 and ( AutoSteeringEngine.isChainPointOnField( vehicle, lx3, lz3 )
 						  or AutoSteeringEngine.isChainPointOnField( vehicle, lx4, lz4 )
	 						or AutoSteeringEngine.isChainPointOnField( vehicle, 0.5 * ( lx3 + lx4), 0.5 * ( lz3 + lz4 ) ) ) )
					or ( vehicle.aseHeadland < 1
					 and ( AutoSteeringEngine.checkField( vehicle, lx3, lz3 )
					    or AutoSteeringEngine.checkField( vehicle, lx4, lz4 )
					    or AutoSteeringEngine.checkField( vehicle, 0.5 * ( lx3 + lx4), 0.5 * ( lz3 + lz4 ) ) ) )

			local lx5 = 0.25 * ( lx1 + lx2 + lx3 + lx4 )
			local lz5 = 0.25 * ( lz1 + lz2 + lz3 + lz4 )
			
			if vehicle.aseFruitAreas == nil then
				vehicle.aseFruitAreas = {}
			end

			vehicle.aseFruitAreas[i] = { lx1, lz1, lx2, lz2, lx3, lz3, lx4, lz4 }

			if vehicle.aseHeadland < 1 then
				if     ( AutoSteeringEngine.checkField( vehicle, lx1, lz1 )
							or AutoSteeringEngine.checkField( vehicle, lx2, lz2 )
							or AutoSteeringEngine.checkField( vehicle, lx3, lz3 )
							or AutoSteeringEngine.checkField( vehicle, lx4, lz4 )
							or AutoSteeringEngine.checkField( vehicle, lx5, lz5 ) )
						and AutoSteeringEngine.getFruitArea( vehicle, xw1,zw1,xw2,zw2, w, vehicle.aseToolParams[i].i, true ) > 0 then
					gotFruits = true;
				end			
			else
				if     ( AutoSteeringEngine.isChainPointOnField( vehicle, lx1, lz1 )
							or AutoSteeringEngine.isChainPointOnField( vehicle, lx2, lz2 )
							or AutoSteeringEngine.isChainPointOnField( vehicle, lx3, lz3 )
							or AutoSteeringEngine.isChainPointOnField( vehicle, lx4, lz4 )
							or AutoSteeringEngine.isChainPointOnField( vehicle, lx5, lz5 ) )
						and AutoSteeringEngine.getFruitArea( vehicle, xw1,zw1,xw2,zw2, w, vehicle.aseToolParams[i].i, true ) > 0 then
					gotFruits = true;
				end			
			end			
						
			if gotFruits then
				if      tool.isSowingMachine
						and tool.aiProhibitedFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN 
						then --and ( tool.lowerStateOnFruits  == nil or not tool.lowerStateOnFruits ) then
					xw1 = xw2
					zw1 = zw2
					xw2 = xw1 + dx
					zw2 = zw1 + dz
					lx1,lz1,lx2,lz2,lx3,lz3 = AutoSteeringEngine.getParallelogram( xw1,zw1,xw2,zw2, w, true )
					lx4 = lx3 + lx2 - lx1
					lz4 = lz3 + lz2 - lz1
					vehicle.aseFruitAreas[i] = { lx1, lz1, lx2, lz2, lx3, lz3, lx4, lz4 }
					
					local area, areaTotal = AutoSteeringEngine.getAIArea( vehicle, 
																																lx1, lz1, lx2, lz2, lx3, lz3, 
																																0, 0, tool.aiProhibitedFruitType, tool.aiProhibitedMinGrowthState, tool.aiProhibitedMaxGrowthState, 
																																0, 0, 0)

					if areaTotal <= 0 or area + area + area <= areaTotal + areaTotal then
						fruitsDetected = true
					else
						gotFruits      = false
					end
				else
					fruitsDetected = true
				end
			elseif  tool.lowerStateOnFruits 
			    and not tool.isSowingMachine then
				-- lower tool in advance
				
				xw1 = xw1 + 2 * dx
				zw1 = zw1 + 2 * dz
				dist = front - back
				repeat 
					xw2 = xw1 + dist * dx
					zw2 = zw1 + dist * dz
					lx1,lz1,lx2,lz2,lx3,lz3 = AutoSteeringEngine.getParallelogram( xw1,zw1,xw2,zw2, w, true )
					lx4 = lx3 + lx2 - lx1
					lz4 = lz3 + lz2 - lz1
					
					dist = dist - 0.5
				until dist < 0.5
						or ( vehicle.aseHeadland >= 1
						 and ( AutoSteeringEngine.isChainPointOnField( vehicle, lx3, lz3 )
								or AutoSteeringEngine.isChainPointOnField( vehicle, lx4, lz4 )
								or AutoSteeringEngine.isChainPointOnField( vehicle, 0.5 * ( lx3 + lx4), 0.5 * ( lz3 + lz4 ) ) ) )
						or ( vehicle.aseHeadland < 1
						 and ( AutoSteeringEngine.checkField( vehicle, lx3, lz3 )
								or AutoSteeringEngine.checkField( vehicle, lx4, lz4 )
								or AutoSteeringEngine.checkField( vehicle, 0.5 * ( lx3 + lx4), 0.5 * ( lz3 + lz4 ) ) ) )

				vehicle.aseFruitAreas[i] = { lx1, lz1, lx2, lz2, lx3, lz3, lx4, lz4 }

				if vehicle.aseHeadland < 1 then
					if     ( AutoSteeringEngine.checkField( vehicle, lx1, lz1 )
								or AutoSteeringEngine.checkField( vehicle, lx2, lz2 )
								or AutoSteeringEngine.checkField( vehicle, lx3, lz3 )
								or AutoSteeringEngine.checkField( vehicle, lx4, lz4 ) )
							and AutoSteeringEngine.getFruitArea( vehicle, xw1,zw1,xw2,zw2, w, vehicle.aseToolParams[i].i, true ) > 0 then
						gotFruits = true;
					end			
				else
					if     ( AutoSteeringEngine.isChainPointOnField( vehicle, lx1, lz1 )
								or AutoSteeringEngine.isChainPointOnField( vehicle, lx2, lz2 )
								or AutoSteeringEngine.isChainPointOnField( vehicle, lx3, lz3 )
								or AutoSteeringEngine.isChainPointOnField( vehicle, lx4, lz4 ) )
							and AutoSteeringEngine.getFruitArea( vehicle, xw1,zw1,xw2,zw2, w, vehicle.aseToolParams[i].i, true ) > 0 then
						gotFruits = true;
					end			
				end		
			end

			AutoSteeringEngine.ensureToolIsLowered( vehicle, gotFruits, i )
		end
	end
	
	return fruitsDetected;
end

------------------------------------------------------------------------
-- hasFruitsSimple
------------------------------------------------------------------------
function AutoSteeringEngine.hasFruitsSimple( vehicle, xw1, zw1, xw2, zw2, off )
	for i=1,table.getn( vehicle.aseTools ) do
		if AutoSteeringEngine.getFruitArea( vehicle, xw1,zw1,xw2,zw2, off, i, true ) > 0 then
			return true
		end
	end
	return false
end

------------------------------------------------------------------------
-- noTurnAtEnd
------------------------------------------------------------------------
function AutoSteeringEngine.noTurnAtEnd( vehicle )

	local noTurn = false;
	if AutoSteeringEngine.hasTools( vehicle ) then
		for i=1,table.getn( vehicle.aseTools ) do
      if vehicle.aseTools[i].isPlough or vehicle.aseTools[i].isSprayer or vehicle.aseTools[i].specialType == "Packomat"
				then noTurn = true end
		end
	end
	
	return noTurn
end

------------------------------------------------------------------------
-- getNoReverseIndex
------------------------------------------------------------------------
function AutoSteeringEngine.getNoReverseIndex( vehicle )

	local noReverseIndex = 0;
	
	if AutoSteeringEngine.hasTools( vehicle ) then
		for i=1,table.getn( vehicle.aseTools ) do
			if vehicle.aseTools[i].aiForceTurnNoBackward and vehicle.aseTools[i].steeringAxleNode ~= nil then
				noReverseIndex = i;
			end
		end
	end
	
	return noReverseIndex;
end

------------------------------------------------------------------------
-- getTurnMode
------------------------------------------------------------------------
function AutoSteeringEngine.getTurnMode( vehicle )
	local revUTurn   = true
	local smallUTurn = true
	local zb         = nil
	local noHire     = false

	if AutoSteeringEngine.hasTools( vehicle ) then
		for i=1,table.getn( vehicle.aseTools ) do
--		local _,_,z = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, vehicle.aseTools[i].refNode ) 
--		z = z + 0.5 * ( vehicle.aseTools[i].zb + vehicle.aseTools[i].z )
--		--print(tostring(zb).." "..tostring(z))
--		if      zb == nil then
--			zb = z
--		elseif  math.abs( z - zb ) > 2
--		    and ( zb > 0 and z < 0
--		       or zb < 0 and z > 0 ) then
--			smallUTurn = false
--		end
			
			if      vehicle.aseTools[i].aiForceTurnNoBackward 
					and vehicle.aseTools[i].steeringAxleNode ~= nil then
				revUTurn   = false
				smallUTurn = false
				break
--			elseif  vehicle.aseTools[i].isSprayer then
--				revUTurn   = false
--				smallUTurn = false
--				break
--		elseif  vehicle.aseTools[i].isCombine 
--				or  vehicle.aseTools[i].isMower then
--			smallUTurn = false
			end
			
			if vehicle.aseTools[i].isSprayer then
				noHire = true
			end
		end
	end
	
	return smallUTurn, revUTurn, noHire
end
		

------------------------------------------------------------------------
-- getToolAngle
------------------------------------------------------------------------
function AutoSteeringEngine.getToolAngle( vehicle )

	local toolAngle = 0;
	local i         = AutoSteeringEngine.getNoReverseIndex( vehicle );
	
	if i>0 then	
		if vehicle.aseTools[i].checkZRotation then
			local zAngle = AutoSteeringEngine.getRelativeZRotation( vehicle.aseChain.refNode, vehicle.aseTools[i].steeringAxleNode )
			if math.abs( zAngle ) > 0.025 then
				local rx2, ry2, rz2 = getRotation( vehicle.aseTools[i].steeringAxleNode )
				setRotation( vehicle.aseTools[i].steeringAxleNode, rx2, ry2, rz2 -zAngle )
				local test = AutoSteeringEngine.getRelativeZRotation( vehicle.aseChain.refNode, vehicle.aseTools[i].steeringAxleNode )
			end
		end
		--toolAngle = AutoSteeringEngine.getRelativeYRotation( vehicle.steeringAxleNode, vehicle.aseTools[i].steeringAxleNode );	
		toolAngle = AutoSteeringEngine.getRelativeYRotation( vehicle.aseChain.refNode, vehicle.aseTools[i].steeringAxleNode );	
		
		if vehicle.aseTools[i].offsetZRotation ~= nil then
			toolAngle = toolAngle + vehicle.aseTools[i].offsetZRotation
		end
		
		if vehicle.aseTools[i].invert then
			if toolAngle < 0 then
				toolAngle = toolAngle + math.pi
			else
				toolAngle = toolAngle - math.pi
			end
		end
	end
	
	return toolAngle;
end

------------------------------------------------------------------------
-- getAngleFactor
------------------------------------------------------------------------
function AutoSteeringEngine.getAngleFactor( maxLooking )
	local f = 1
	if maxLooking ~= nil then
		f = math.min( math.max( maxLooking / math.rad( ASEGlobals.maxLooking ), 0.1 ), ASEGlobals.maxLooking )
	end
	return math.rad( f * ASEGlobals.angleStep * ASEGlobals.chainLen / ASEGlobals.angleMax );	
end

------------------------------------------------------------------------
-- setSteeringAngle
------------------------------------------------------------------------
function AutoSteeringEngine.setSteeringAngle( vehicle, angle )
	if ASEGlobals.zeroAngle > 0 then
		vehicle.aseSteeringAngle = 0
	elseif vehicle.aseSteeringAngle == nil or math.abs( vehicle.aseSteeringAngle - angle ) > 1E-3 then
		AutoSteeringEngine.setChainStatus( vehicle, 1, ASEStatus.initial );
		vehicle.aseSteeringAngle = angle
	end 
	if vehicle.aseMinAngle == nil or vehicle.aseMaxAngle == nil then
		vehicle.aseSteeringAngle = angle;
	else
		vehicle.aseSteeringAngle = math.min( math.max( angle, vehicle.aseMinAngle ), vehicle.aseMaxAngle );
	end
end

------------------------------------------------------------------------
-- currentSteeringAngle
------------------------------------------------------------------------
function AutoSteeringEngine.currentSteeringAngle( vehicle, isInverted )
	local steeringAngle = 0;		

	if      vehicle.articulatedAxis ~= nil 
			and vehicle.articulatedAxis.componentJoint ~= nil
			and vehicle.articulatedAxis.componentJoint.jointNode ~= nil then
		steeringAngle = math.min( math.max( -vehicle.lastRotatedTime * vehicle.articulatedAxis.rotSpeed, vehicle.articulatedAxis.rotMin ), vehicle.articulatedAxis.rotMax );
	else
		for _,wheel in pairs(vehicle.wheels) do
			if math.abs(wheel.rotSpeed) > 1E-3 then
				if math.abs( wheel.steeringAngle ) > math.abs( steeringAngle ) then
					if wheel.rotSpeed > 0 then
						steeringAngle = wheel.steeringAngle
					else
						steeringAngle = -wheel.steeringAngle
					end
				end
			end
		end
	end	
	
	--if isInverted or ( isInverted == nil and vehicle.aseChain ~= nil and vehicle.aseChain.isInverted ) then
	--	steeringAngle = -steeringAngle
	--end
	
	if vehicle.aseSteeringAngle ~= nil and 0 < ASEGlobals.average and ASEGlobals.average < 1 then
		steeringAngle = ASEGlobals.average * steeringAngle + (1-ASEGlobals.average) * vehicle.aseSteeringAngle;
	end
	
	--local neg = false
	--if steeringAngle < 0 then neg = true end
	--
	--local f = math.rad(3)
	--
	--steeringAngle = f * math.floor( math.abs( steeringAngle / f ) + 0.5 )
	--if neg then steeringAngle = -steeringAngle end
	
	if ASEGlobals.zeroAngle > 0 then
		AutoSteeringEngine.setSteeringAngle( vehicle, 0 );
	else
		AutoSteeringEngine.setSteeringAngle( vehicle, steeringAngle );
	end
	
	return steeringAngle
end

------------------------------------------------------------------------
-- steer
------------------------------------------------------------------------
function AutoSteeringEngine.steer( vehicle, dt, angle, aiSteeringSpeed, directSteer )
-- precondition: vehicle.rotatedTime is filled from last steering
	if vehicle.aseChain.isInverted then
		angle = -angle
	end
	
	if     angle == 0 then
		targetRotTime = 0
	elseif angle  > 0 then
		targetRotTime = vehicle.maxRotTime * math.min( angle / vehicle.aseChain.maxSteering, 1)
	else
		targetRotTime = vehicle.minRotTime * math.min(-angle / vehicle.aseChain.maxSteering, 1)
	end
	
	local aiDirectSteering = ASEGlobals.aiSteering2
	if vehicle.articulatedAxis ~= nil then --or vehicle.acHasRoueSpec then
		aiDirectSteering = ASEGlobals.aiSteering3
	end
	
	if directSteer then
		local diff = dt * aiSteeringSpeed;
		if aiDirectSteering <= 0 then
			diff = math.min( diff+diff+diff+diff+diff+diff, math.abs( math.min( 1, -aiDirectSteering ) * ( targetRotTime - vehicle.rotatedTime ) ) )
		else
			diff = aiDirectSteering * diff
		end
		
		if targetRotTime < vehicle.rotatedTime then
			diff = -diff
		end
		
		if targetRotTime > vehicle.rotatedTime then
			vehicle.rotatedTime = math.min(vehicle.rotatedTime + diff, targetRotTime)
		else
			vehicle.rotatedTime = math.max(vehicle.rotatedTime + diff, targetRotTime)
		end
	else
		if targetRotTime > vehicle.rotatedTime then
			vehicle.rotatedTime = math.min(vehicle.rotatedTime + ASEGlobals.aiSteering * dt * aiSteeringSpeed, targetRotTime)
		else
			vehicle.rotatedTime = math.max(vehicle.rotatedTime - ASEGlobals.aiSteering * dt * aiSteeringSpeed, targetRotTime)
		end
	end
	
	if ASEGlobals.zeroAngle > 0 then
		vehicle.aseSteeringAngle = 0
	elseif vehicle.aseSteeringAngle == nil or math.abs( vehicle.aseSteeringAngle - angle ) > 1E-3 then
		AutoSteeringEngine.setChainStatus( vehicle, 1, ASEStatus.initial );
		vehicle.aseSteeringAngle = angle
	end 
end

------------------------------------------------------------------------
-- drive
------------------------------------------------------------------------
function AutoSteeringEngine.drive( vehicle, dt, acceleration, allowedToDrive, moveForwards, speedLevel, useReduceSpeed, slowMaxRpmFactor )

	if moveForwards ~= nil and vehicle.aseChain.isInverted then
		moveForwards = not moveForwards
	end
	
  if vehicle.firstTimeRun then
    local acc = acceleration
		local disableChangingDirection = false
		local doHandBrake = false

    if speedLevel ~= nil and speedLevel ~= 0 then
      acc = vehicle.motor.accelerations[speedLevel]
      vehicle.motor:setSpeedLevel(speedLevel, true)
      if useReduceSpeed then
        vehicle.motor.maxRpmOverride = vehicle.motor.maxRpm[speedLevel] * slowMaxRpmFactor
      else
        vehicle.motor.maxRpmOverride = nil
      end
    elseif useReduceSpeed then
      acc = acc * slowMaxRpmFactor
    end
		
    if not moveForwards then
      acc = -acc
    end
		
    if not allowedToDrive then
      acc = 0
			if vehicle.isRealistic and WheelsUtil.updateWheelsPhysicsMR ~= nil then
	--********************************  DURAL  *************************************************************
	-- "computing" braking acc
				if math.abs(vehicle.realGroundSpeed)>0.5 then
					acc = -math.min(1, vehicle.realGroundSpeed/3)*Utils.sign(vehicle.movingDirection); --braking function of speed
					disableChangingDirection = true; -- we want the AI to brake, not reversing
				else
					doHandBrake = true
				end
	--********************************  END DURAL  *************************************************************
			end
		end

    if vehicle.maxAccelerationSpeed ~= nil then
      acc = Steerable.calculateRealAcceleration(vehicle, acc, dt)
    end
		
		if vehicle.isRealistic and WheelsUtil.updateWheelsPhysicsMR ~= nil then			
			WheelsUtil.updateWheelsPhysicsMR(vehicle, dt, vehicle.lastSpeed, acc, doHandBrake, vehicle.requiredDriveMode, disableChangingDirection);
		else
			WheelsUtil.updateWheelsPhysics(vehicle, dt, vehicle.lastSpeed, acc, not allowedToDrive, vehicle.requiredDriveMode)
		end
  end
end

------------------------------------------------------------------------
-- drawMarker
------------------------------------------------------------------------
function AutoSteeringEngine.drawMarker( vehicle )

	if not vehicle.isServer then return end
	
	if vehicle.debugRendering then
		AutoSteeringEngine.displayDebugInfo( vehicle )
	end

	if vehicle.aseHeadland > 0 and vehicle.aseWidth ~= nil then		
		setRotation( vehicle.aseChain.headlandNode, 0, -AutoSteeringEngine.getTurnAngle( vehicle ), 0 );
		local w = math.max( 1, 0.25 * vehicle.aseWidth )--+ 0.13 * vehicle.aseHeadland );		
		local x1,y1,z1 = localToWorld( vehicle.aseChain.headlandNode, -2 * w, 1, vehicle.aseHeadland );
		local x2,y2,z2 = localToWorld( vehicle.aseChain.headlandNode,  2 * w, 1, vehicle.aseHeadland );
		y1 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x1, 1, z1) + 1
		y2 = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x2, 1, z2) + 1
		drawDebugLine( x1,y1,z1, 1,1,0, x2,y2,z2, 1,1,0 );
	end

	--if vehicle.aseCollisionPoints ~= nil and table.getn( vehicle.aseCollisionPoints ) > 0 then
	--	for _,p in pairs(vehicle.aseCollisionPoints) do
	--		local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, p.x, 1, p.z)
	--		drawDebugLine(  p.x,y,p.z, 1,0,0, p.x,y+2,p.z, 1,0,0 );
	--		drawDebugPoint( p.x,y+2,p.z, 1, 1, 1, 1 )
	--	end
	--end
	
	if vehicle.aseToolParams ~= nil and table.getn( vehicle.aseToolParams ) > 0 then
		local px,py,pz;
		local off = 1
		if not vehicle.aseLRSwitch then
			off = -off;
		end
					
		for j=1,table.getn(vehicle.aseToolParams) do
			local tp = vehicle.aseToolParams[j];
			
			for _,m in pairs(vehicle.aseTools[tp.i].marker) do
				local x,y,z = getWorldTranslation( m )
				y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
				drawDebugLine(  x,y,z, 0,0,1, x,y+2,z, 0,0,1 );
				drawDebugPoint( x,y+2,z, 1, 1, 1, 1 )
			end
			
			if vehicle.aseTools[tp.i].aiBackMarker ~= nil then
				local x,y,z = getWorldTranslation( vehicle.aseTools[tp.i].aiBackMarker )
				y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
				drawDebugLine(  x,y,z, 0,1,0, x,y+2,z, 0,1,0 );
				drawDebugPoint( x,y+2,z	, 1, 1, 1, 1 )
			end
		end
	end
end
	
------------------------------------------------------------------------
-- drawLines
------------------------------------------------------------------------
function AutoSteeringEngine.drawLines( vehicle )

	if not vehicle.isServer then return end
	
	if vehicle.debugRendering then
		AutoSteeringEngine.displayDebugInfo( vehicle )
	end

	local x,_,z = getWorldTranslation( vehicle.aseChain.refNode );
	local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
	drawDebugLine(  x, y, z,0,1,0, x, y+4, z,0,1,0);
	drawDebugPoint( x, y+4, z	, 1, 1, 1, 1 )
	local x1,_,z1 = localToWorld( vehicle.aseChain.refNode ,0,0,2 )
	drawDebugLine(  x1, y+3, z1,0,1,0, x, y+3, z,0,1,0);
	
	if      vehicle.aseDirectionBeforeTurn ~= nil 
			and vehicle.aseDirectionBeforeTurn.x ~= nil 
			and vehicle.aseDirectionBeforeTurn.z	~= nil 
			and vehicle.acTurnStage ~= nil 
			and vehicle.acTurnStage ~= 0 then
		local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, vehicle.aseDirectionBeforeTurn.x, 1, vehicle.aseDirectionBeforeTurn.z)

		drawDebugLine(  vehicle.aseDirectionBeforeTurn.x, y, vehicle.aseDirectionBeforeTurn.z,1,0,0,vehicle.aseDirectionBeforeTurn.x, y+2, vehicle.aseDirectionBeforeTurn.z,1,0,0);
		drawDebugPoint( vehicle.aseDirectionBeforeTurn.x, y+2, vehicle.aseDirectionBeforeTurn.z	, 1, 1, 1, 1 )

		local dx, _,dz  = localDirectionToWorld( vehicle.aseChain.headlandNode, 0, 0, -5 )
		local xw1,zw1,xw2,zw2 
		xw1 = vehicle.aseDirectionBeforeTurn.x + dx
		zw1 = vehicle.aseDirectionBeforeTurn.z + dz
		xw2 = vehicle.aseDirectionBeforeTurn.x
		zw2 = vehicle.aseDirectionBeforeTurn.z

		local lx1,lz1,lx2,lz2,lx3,lz3 = AutoSteeringEngine.getParallelogram( xw1,zw1,xw2,zw2, 1 );
		drawDebugLine(lx1,y+1,lz1,0,1,1,lx3,y+1,lz3,0,1,1);
		drawDebugLine(lx1,y+1,lz1,0,1,1,lx2,y+1,lz2,0,1,1);
		local lx4 = lx3 + lx2 - lx1;
		local lz4 = lz3 + lz2 - lz1;
		drawDebugLine(lx4,y+1,lz4,0,1,1,lx2,y+1,lz2,0,1,1);
		drawDebugLine(lx4,y+1,lz4,0,1,1,lx3,y+1,lz3,0,1,1);
		lx1,lz1,lx2,lz2,lx3,lz3 = AutoSteeringEngine.getParallelogram( xw1,zw1,xw2,zw2, -1 );
		drawDebugLine(lx1,y+1,lz1,0,1,1,lx3,y+1,lz3,0,1,1);
		drawDebugLine(lx1,y+1,lz1,0,1,1,lx2,y+1,lz2,0,1,1);
		lx4 = lx3 + lx2 - lx1;
		lz4 = lz3 + lz2 - lz1;
		drawDebugLine(lx4,y+1,lz4,0,1,1,lx2,y+1,lz2,0,1,1);
		drawDebugLine(lx4,y+1,lz4,0,1,1,lx3,y+1,lz3,0,1,1);
		
		
		dx,dz = AutoSteeringEngine.getTurnVector( vehicle, true )		
		xw1,_,zw1   = localToWorld( vehicle.aseChain.headlandNode, -dx, 0, -dz )
		drawDebugLine(  xw1, y, zw1, 1,0,0, xw1, y+2, zw1 ,1,0,0);
		drawDebugPoint( xw1, y+2, zw1 , 1, 1, 1, 1 )		
	end		
		
	if vehicle.aseHeadland > 0 then		
		setRotation( vehicle.aseChain.headlandNode, 0, -AutoSteeringEngine.getTurnAngle( vehicle ), 0 );
		local w = math.max( 1, 0.25 * vehicle.aseWidth )--+ 0.13 * vehicle.aseHeadland );
		for j=-2,2 do
			local d = vehicle.aseHeadland + 1;
			local x,_,z = localToWorld( vehicle.aseChain.headlandNode, j * w, 1, d );
			local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z) + 1
			if AutoSteeringEngine.checkField( vehicle, x,z) then
				drawDebugPoint( x,y,z	, 0, 1, 0, 1 )
			else
				drawDebugPoint( x,y,z	, 1, 0, 0, 1 )
			end
			d = - vehicle.aseHeadland - 1;
			x,_,z = localToWorld( vehicle.aseChain.headlandNode, j * w, 1, d );
			y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z) + 1
			if AutoSteeringEngine.checkField( vehicle, x,z) then
				drawDebugPoint( x,y,z	, 0, 1, 0, 1 )
			else
				drawDebugPoint( x,y,z	, 1, 0, 0, 1 )
			end
		end
	end

	if vehicle.aseToolParams ~= nil and table.getn( vehicle.aseToolParams ) > 0 then
		local px,py,pz;
		local off = 1
		if not vehicle.aseLRSwitch then
			off = -off;
		end
					
		for j=1,table.getn(vehicle.aseToolParams) do
			local tp = vehicle.aseToolParams[j];
			if      vehicle.aseTools ~= nil
					and tp.i ~= nil 
					and vehicle.aseTools[tp.i] ~= nil 
					and vehicle.aseTools[tp.i].marker ~= nil then			
				for _,m in pairs(vehicle.aseTools[tp.i].marker) do
					local xl,_,zl = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, m )
					if Utils.vector2LengthSq( xl-tp.x, zl-tp.z ) > 0.01 then
						local x,_,z = getWorldTranslation( m )
						local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
						drawDebugLine(  x,y,z, 0,0,1, x,y+2,z, 0,0,1 );
						drawDebugPoint( x,y+2,z, 1, 1, 1, 1 )
					end
				end
			
				if vehicle.aseTools[tp.i].aiBackMarker  ~= nil then
					local x,_,z = getWorldTranslation( vehicle.aseTools[tp.i].aiBackMarker )
					local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
					drawDebugLine(  x,y,z, 0,1,0, x,y+2,z, 0,1,0 );
					drawDebugPoint( x,y+2,z	, 1, 1, 1, 1 )
				end
				
				if vehicle.aseTools[tp.i].aiForceTurnNoBackward then
					local x,y,z
					x,_,z = localToWorld( vehicle.aseChain.refNode, 0, 0, tp.b1 )
					y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
					drawDebugLine(  x,y,z, 1,0,0, x,y+2,z, 1,0,0 );
					drawDebugPoint( x,y+2,z	, 1, 1, 1, 1 )

					local a = -AutoSteeringEngine.getToolAngle( vehicle );
					local l = tp.b1 + tp.b2;
				--print(tostring(tp.b1).." "..tostring(tp.b2).." "..tostring(math.deg(a)))
					
					x,_,z = localToWorld( vehicle.aseChain.refNode, math.sin(a) * l, 0, math.cos(a) * l )
					y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
					drawDebugLine(  x,y,z, 1,0,0, x,y+2,z, 1,0,0 );
					drawDebugPoint( x,y+2,z	, 1, 1, 1, 1 )
				end
				
				x,_,z = localToWorld( vehicle.aseChain.refNode, tp.x, 0, tp.z )
				y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z)
				drawDebugLine(  x,y,z, 1,0,0, x,y+2,z, 1,0,0 );
				drawDebugPoint( x,y+2,z	, 1, 1, 1, 1 )
				
				for i=1,ASEGlobals.chainMax+1 do
					local x, z = AutoSteeringEngine.getChainPoint( vehicle, i, tp )
					local wx,wy,wz = localToWorld( vehicle.aseChain.nodes[i].index ,x, 1, z );
					wy = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, wx, 1, wz) + 1
				
					if i>1 then
						local lx1,lz1,lx2,lz2,lx3,lz3 = AutoSteeringEngine.getParallelogram( px, pz, wx, wz, off );
						local y = 0.5 * ( py + wy );

						local fRes = AutoSteeringEngine.isChainPointOnField( vehicle, px, pz ) and AutoSteeringEngine.isChainPointOnField( vehicle, wx, wz )

						if fRes then
							if AutoSteeringEngine.getFruitArea( vehicle, px, px, wx, wz, -off, tp.i ) > 0 then
								drawDebugLine(lx1,py,lz1,0,1,0,lx3,y,lz3,0,1,0);
							else
								drawDebugLine(lx1,py,lz1,1,1,0,lx3,y,lz3,1,1,0);
							end
						else
							drawDebugLine(lx1,py,lz1,1,0,0,lx3,y,lz3,1,0,0);
						end
						drawDebugLine(lx1,py,lz1,0,0,1,lx2,y,lz2,0,0,1);
					end
					px = wx; 
					py = wy; 
					pz = wz;
				end		
			end

			y = y + 1
			if vehicle.aseFruitAreas ~= nil and vehicle.aseFruitAreas[j] ~= nil and table.getn( vehicle.aseFruitAreas[j] ) == 8 then
				local lx1,lz1,lx2,lz2,lx3,lz3,lx4,lz4 = unpack( vehicle.aseFruitAreas[j] )
				drawDebugLine(lx1,y,lz1,0,1,1,lx3,y,lz3,0,1,1);
				drawDebugLine(lx1,y,lz1,0,1,1,lx2,y,lz2,0,1,1);
				drawDebugLine(lx4,y,lz4,0,1,1,lx2,y,lz2,0,1,1);
				drawDebugLine(lx4,y,lz4,0,1,1,lx3,y,lz3,0,1,1);
			elseif vehicle.aseFruitAreas ~= nil and vehicle.aseFruitAreas[j] ~= nil then
				print(tostring(table.getn( vehicle.aseFruitAreas[j] ) ) )
			end
		end
	end
	
	if ASEGlobals.showChannels > 0 then
		if vehicle.aseTestMap == nil and vehicle.aseCurrentField ~= nil then
			vehicle.aseTestMap = vehicle.aseCurrentField.getPoints()
			if vehicle.aseTestMap ~= nil then
				print(string.format("points: %i",table.getn(vehicle.aseTestMap)))
			end
		end
		
		if vehicle.aseTestMap ~= nil then
			for _,p in pairs( vehicle.aseTestMap ) do
				x,z = unpack( p )
				local y = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 1, z) + 2.2
				drawDebugPoint( x, y, z, 1,1,1, 1 )
			end
		end
	end
	
	if      vehicle.aseDirectionBeforeTurn             ~= nil 
			and vehicle.aseDirectionBeforeTurn.targetTrace ~= nil then
		for i,p in pairs( vehicle.aseDirectionBeforeTurn.targetTrace ) do
			drawDebugLine(  p.x, y, p.z,0,1,0, p.x, y+4, p.z,0,1,0);
			drawDebugPoint( p.x, y+4, p.z	, 1, 1, 1, 1 )
		end
	end
	
end

------------------------------------------------------------------------
-- displayDebugInfo
------------------------------------------------------------------------
function AutoSteeringEngine.displayDebugInfo( vehicle )

	if vehicle.isControlled then
		setTextBold(false);
		setTextColor(1, 1, 1, 1);
		setTextAlignment(RenderText.ALIGN_LEFT);
		
		local fullText = "";
		
		fullText = fullText .. string.format("AutoTractor:") .. "\n";
		
		renderText(0.51, 0.97, 0.02, fullText);		
	end
	
end

------------------------------------------------------------------------
-- getFruitArea
------------------------------------------------------------------------
function AutoSteeringEngine.getFruitArea( vehicle, x1,z1,x2,z2,d,toolIndex,noMinLength )

  --if ASEGlobals.stepLog2 < 4 then
	return AutoSteeringEngine.getFruitAreaNoBuffer( vehicle, x1,z1,x2,z2,d, vehicle.aseTools[toolIndex],noMinLength )
	--else
	--end 
	
end

------------------------------------------------------------------------
-- getFruitAreaNoBuffer
------------------------------------------------------------------------
--local showOnce1 = true
function AutoSteeringEngine.getFruitAreaNoBuffer( vehicle, x1,z1,x2,z2,d,tool,noMinLength )
	local lx1,lz1,lx2,lz2,lx3,lz3 = AutoSteeringEngine.getParallelogram( x1, z1, x2, z2, d, noMinLength );

	local area, areaTotal = 0,0;
	if tool.isCombine then
		area, areaTotal = Utils.getFruitArea(tool.obj.lastValidInputFruitType, lx1,lz1,lx2,lz2,lx3,lz3,false);	
	elseif tool.isMower then
		area, areaTotal = Utils.getFruitArea(FruitUtil.FRUITTYPE_GRASS, lx1,lz1,lx2,lz2,lx3,lz3,false);	
	elseif tool.isWindrower then
		area, areaTotal = AutoSteeringEngine.getWindrowArea(lx1,lz1,lx2,lz2,lx3,lz3)
	elseif tool.isTedder then
		area, areaTotal = AutoSteeringEngine.getFruitWindrowArea(FruitUtil.FRUITTYPE_GRASS,lx1,lz1,lx2,lz2,lx3,lz3)
	else
		local terrainDetailProhibitedMask           = tool.aiTerrainDetailProhibitedMask
		local terrainDetailRequiredFruitType				= tool.aiRequiredFruitType
		local terrainDetailRequiredMinGrowthState	  = tool.aiRequiredMinGrowthState
		local terrainDetailRequiredMaxGrowthState	  = tool.aiRequiredMaxGrowthState
		local terrainDetailProhibitedFruitType      = tool.aiProhibitedFruitType
		local terrainDetailProhibitedMinGrowthState = tool.aiProhibitedMinGrowthState
		local terrainDetailProhibitedMaxGrowthState = tool.aiProhibitedMaxGrowthState
		local terrainDetailRequiredMask             = 0
		if 0 <= tool.aiTerrainDetailChannel1 then
			terrainDetailRequiredMask = bitOR(terrainDetailRequiredMask, 2 ^ tool.aiTerrainDetailChannel1)
			if 0 <= tool.aiTerrainDetailChannel2 then
				terrainDetailRequiredMask = bitOR(terrainDetailRequiredMask, 2 ^ tool.aiTerrainDetailChannel2)
				if 0 <= tool.aiTerrainDetailChannel3 then
					terrainDetailRequiredMask = bitOR(terrainDetailRequiredMask, 2 ^ tool.aiTerrainDetailChannel3)
				end
			end
		end
		
		area, areaTotal = AutoSteeringEngine.getAIArea( vehicle, 
																										lx1, lz1, lx2, lz2, lx3, lz3, 
																										terrainDetailRequiredMask, 
																										terrainDetailProhibitedMask , 
																										terrainDetailRequiredFruitType, 
																										terrainDetailRequiredMinGrowthState, 
																										terrainDetailRequiredMaxGrowthState, 
																										terrainDetailProhibitedFruitType, 
																										terrainDetailProhibitedMinGrowthState, 
																										terrainDetailProhibitedMaxGrowthState)
	end
	
	return area, areaTotal;
end

------------------------------------------------------------------------
-- getFruitWindrowArea
------------------------------------------------------------------------
function AutoSteeringEngine.getFruitWindrowArea(fruitId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
  local ids = g_currentMission.fruits[fruitId]
  if ids == nil or ids.windrowId == 0 then
    return 0,0
  end
  local windrowId = ids.windrowId
  local maskId = windrowId
  local numMaskChannels = g_currentMission.numWindrowChannels
  local x, z, widthX, widthZ, heightX, heightZ = Utils.getXZWidthAndHeight(windrowId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
  local _,area,totalArea = getDensityMaskedParallelogram(windrowId, x, z, widthX, widthZ, heightX, heightZ, 0, g_currentMission.numWindrowChannels, maskId, 0, numMaskChannels, value)
  return area,totalArea
end

------------------------------------------------------------------------
-- getWindrowArea
------------------------------------------------------------------------
function AutoSteeringEngine.getWindrowArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
  local fruitType = FruitUtil.FRUITTYPE_DRYGRASS
  local area,totalArea = AutoSteeringEngine.getFruitWindrowArea(fruitType, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
  if area == 0 then
    for fruitId = 1, FruitUtil.NUM_FRUITTYPES do
      if fruitId ~= FruitUtil.FRUITTYPE_DRYGRASS then
        local ids = g_currentMission.fruits[fruitId]
        if ids ~= nil and ids.windrowId ~= 0 then
          fruitType = fruitId
          area,totalArea = AutoSteeringEngine.getFruitWindrowArea(fruitType, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
          if area > 0 then
						local a, t = Utils.getFruitWindrowArea(fruitType, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
						area = math.max( area - a, 0 )
            break
          end
        end
      end
    end
  end
  return area,totalArea
end

------------------------------------------------------------------------
-- getAIArea
------------------------------------------------------------------------
function AutoSteeringEngine.getAIArea( vehicle, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, terrainDetailRequiredMask, terrainDetailProhibitedMask, requiredFruitType, requiredMinGrowthState, requiredMaxGrowthState, prohibitedFruitType, prohibitedMinGrowthState, prohibitedMaxGrowthState)
	if false then
		return AITractor.getAIArea( vehicle, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, terrainDetailRequiredMask, terrainDetailProhibitedMask, requiredFruitType, requiredMinGrowthState, requiredMaxGrowthState, prohibitedFruitType, prohibitedMinGrowthState, prohibitedMaxGrowthState);
	else
    local area = 0;
    local totalArea = 1;
    if terrainDetailRequiredMask > 0 then
        local detailId = g_currentMission.terrainDetailId;
        local x,z, widthX,widthZ, heightX,heightZ = Utils.getXZWidthAndHeight(detailId, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
        setDensityCompareParams(detailId, "greater", 0, 0, terrainDetailRequiredMask, terrainDetailProhibitedMask);
        _,area,totalArea = getDensityParallelogram(detailId, x, z, widthX, widthZ, heightX, heightZ, g_currentMission.terrainDetailAIFirstChannel, g_currentMission.terrainDetailAINumChannels);
        if prohibitedFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
            local ids = g_currentMission.fruits[prohibitedFruitType];
            if ids ~= nil and ids.id ~= 0 then
                setDensityMaskParams(detailId, "between", prohibitedMinGrowthState+1, prohibitedMaxGrowthState+1); -- only fruit outside the given range is allowed
                local _,prohibitedArea = getDensityMaskedParallelogram(detailId, x, z, widthX, widthZ, heightX, heightZ, g_currentMission.terrainDetailAIFirstChannel, g_currentMission.terrainDetailAINumChannels, ids.id, 0, g_currentMission.numFruitStateChannels);
                setDensityMaskParams(detailId, "greater", 0);
                area = area - prohibitedArea;
							end
        end
        setDensityCompareParams(detailId, "greater", -1);
    elseif requiredFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
        local ids = g_currentMission.fruits[requiredFruitType];
        if ids ~= nil and ids.id ~= 0 then
            local x,z, widthX,widthZ, heightX,heightZ = Utils.getXZWidthAndHeight(ids.id, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);
            setDensityCompareParams(ids.id, "between", requiredMinGrowthState+1, requiredMaxGrowthState+1);
            if terrainDetailProhibitedMask ~= 0 then
                local detailId = g_currentMission.terrainDetailId;
                setDensityMaskParams(ids.id, "greater", 0, 0, 0, terrainDetailProhibitedMask);
                _,area,totalArea = getDensityMaskedParallelogram(ids.id, x, z, widthX, widthZ, heightX, heightZ, 0, g_currentMission.numFruitStateChannels, detailId, g_currentMission.terrainDetailAIFirstChannel, g_currentMission.terrainDetailAINumChannels);
                setDensityMaskParams(ids.id, "greater", 0);
            else
                _,area,totalArea = getDensityParallelogram(ids.id, x, z, widthX, widthZ, heightX, heightZ, 0, g_currentMission.numFruitStateChannels);
            end
            setDensityCompareParams(ids.id, "greater", -1);
        end
    end
    return area,totalArea;
	end
end

------------------------------------------------------------------------
-- applySteering
------------------------------------------------------------------------
function AutoSteeringEngine.applySteering( vehicle )

	if vehicle.aseMinAngle == nil or vehicle.aseMaxAngle == nil then
		vehicle.aseMinAngle = -vehicle.aseChain.maxSteering;
		vehicle.aseMaxAngle = vehicle.aseChain.maxSteering;
	end

	local a  = vehicle.aseSteeringAngle;
	local j0 = ASEGlobals.chainMax+2;
	local af
	if ASEGlobals.zeroAngle > 0 then
		af = vehicle.aseMaxAngle / ASEGlobals.angleMax 
		if not vehicle.aseLRSwitch	then
			af = -af
		end 
	else
		af = vehicle.aseAngleFactor
	end
	
	for j=1,ASEGlobals.chainMax+1 do 
		local b = a + af * vehicle.aseChain.nodes[j].angle;
		a  = math.min( math.max( b, vehicle.aseMinAngle ), vehicle.aseMaxAngle );
		af = vehicle.aseAngleFactor

		if j0 > j and vehicle.aseChain.nodes[j].status < ASEStatus.steering then
			j0 = j
		end
		if j >= j0 then
			vehicle.aseChain.nodes[j].steering  = a;
			vehicle.aseChain.nodes[j].tool      = {};
			vehicle.aseChain.nodes[j].radius    = 0;
			if math.abs(a) > 1E-5 then
				vehicle.aseChain.nodes[j].radius  = vehicle.aseChain.wheelBase / math.tan( a );
			end
			vehicle.aseChain.nodes[j].status    = ASEStatus.steering;
		end
	end 
end

------------------------------------------------------------------------
-- applyRotation
------------------------------------------------------------------------
function AutoSteeringEngine.applyRotation( vehicle )

	if not vehicle.isServer then return end
	
	AutoSteeringEngine.applySteering( vehicle );

	local j0 = ASEGlobals.chainMax+2;
	for j=1,ASEGlobals.chainMax do 
		if j0 > j and vehicle.aseChain.nodes[j].status < ASEStatus.rotation then
			j0 = j
		end
		if j >= j0 then
			vehicle.aseChain.nodes[j].rotation = math.tan( vehicle.aseChain.nodes[j].steering ) * vehicle.aseChain.invWheelBase;

			--if vehicle.aseChain.isInverted then
			--	vehicle.aseChain.nodes[j].rotation = -vehicle.aseChain.nodes[j].rotation
			--end
	
			setRotation( vehicle.aseChain.nodes[j].index2, 0, vehicle.aseChain.nodes[j].rotation, 0 );
			vehicle.aseChain.nodes[j].status   = ASEStatus.rotation;
		end
	end 
end

------------------------------------------------------------------------
-- checkChain
------------------------------------------------------------------------
function AutoSteeringEngine.invalidateField( vehicle )
	vehicle.aseFieldIsInvalid = true
end

------------------------------------------------------------------------
-- checkFieldNoBuffer
------------------------------------------------------------------------
 function AutoSteeringEngine.checkFieldNoBuffer( x, z, checkFunction ) 

	if x == nil or z == nil or checkFunction == nil then
		--Mogli.printCallstack()
		return false
	end 
	
	FieldBitmap.prepareIsField( )
	local startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = FieldBitmap.getParallelogram( x, z, 0.5, 0.25 )
	local ret = checkFunction( startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ )
	FieldBitmap.cleanupAfterIsField( )
	
	return ret
end

------------------------------------------------------------------------
-- hasMower
------------------------------------------------------------------------
function AutoSteeringEngine.hasMower( vehicle )
	if AutoSteeringEngine.hasTools( vehicle ) then
		for i=1,table.getn( vehicle.aseTools ) do
			if vehicle.aseTools[i].isMower or ( vehicle.aseTools[i].isCombine and vehicle.aseTools[i].obj.lastValidInputFruitType == FruitUtil.FRUITTYPE_GRASS ) then
				return true
			end
		end
	end
	
	return false
end

------------------------------------------------------------------------
-- hasWindrower
------------------------------------------------------------------------
function AutoSteeringEngine.hasWindrower( vehicle )
	if AutoSteeringEngine.hasTools( vehicle ) then
		for i=1,table.getn( vehicle.aseTools ) do
			if vehicle.aseTools[i].isWindrower then
				return true
			end
		end
	end
	
	return false
end

------------------------------------------------------------------------
-- hasTedder
------------------------------------------------------------------------
function AutoSteeringEngine.hasTedder( vehicle )
	if AutoSteeringEngine.hasTools( vehicle ) then
		for i=1,table.getn( vehicle.aseTools ) do
			if vehicle.aseTools[i].isTedder then
				return true
			end
		end
	end
	
	return false
end

------------------------------------------------------------------------
-- areaTotalSpecial
------------------------------------------------------------------------
function AutoSteeringEngine.areaTotalSpecial( x, z, ownedBy, mode, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ )
	
	local dx = x - startWorldX
	local dz = z - startWorldZ
	if ownedBy then
		local lx4 = heightWorldX + widthWorldX - startWorldX;
		local lz4 = heightWorldZ + widthWorldZ - startWorldZ;
		if      not g_currentMission:getIsFieldOwnedAtWorldPos( startWorldX,  startWorldZ )
				and not g_currentMission:getIsFieldOwnedAtWorldPos( widthWorldX,  widthWorldZ )
				and not g_currentMission:getIsFieldOwnedAtWorldPos( heightWorldX, heightWorldZ )
				and not g_currentMission:getIsFieldOwnedAtWorldPos( lx4, lz4 ) then
			return 0,0
		end
	end
	if Utils.vector2LengthSq( dx, dz ) > 1000000 then 
		return 0,0 
	end
	
  local a, t = 0, 0
	if     mode == 1 then
		a, t = Utils.getFruitArea( FruitUtil.FRUITTYPE_GRASS, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, false );	
	elseif mode == 2 then
		a, t = AutoSteeringEngine.getWindrowArea(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);	
	elseif mode == 3 then
		a, t = AutoSteeringEngine.getFruitWindrowArea(FruitUtil.FRUITTYPE_GRASS, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ);	
	end
	
	if      widthWorldX - startWorldX < 2 
			and widthWorldZ - startWorldZ < 2 
			and a+a+a+a < t+t+t then
		a = 0
	end
	return a,t
end

function AutoSteeringEngine.checkSpecialField( x, z, ownedBy, mode, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ )
	return ( 0 < AutoSteeringEngine.areaTotalSpecial( x, z, ownedBy, mode, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ ) )
end

------------------------------------------------------------------------
-- getCheckFunction
------------------------------------------------------------------------
function AutoSteeringEngine.getCheckFunction( vehicle )

	local checkFct, areaTotalFct
	
	if     AutoSteeringEngine.hasMower( vehicle ) 
			or AutoSteeringEngine.hasWindrower( vehicle )
			or AutoSteeringEngine.hasTedder( vehicle ) then 	
		local x1,_,z1= localToWorld( vehicle.aseChain.refNode, 0.5 * ( vehicle.aseActiveX + vehicle.aseOtherX ), 0, 0 )
		local buffer = {}
		buffer.x     = x1
		buffer.z     = z1
		buffer.o     = g_currentMission:getIsFieldOwnedAtWorldPos( buffer.x, buffer.z )
		buffer.m     = 0
		
		if     AutoSteeringEngine.hasMower( vehicle ) then
			buffer.m = 1
		elseif AutoSteeringEngine.hasWindrower( vehicle ) then		
			buffer.m = 2
		elseif AutoSteeringEngine.hasTedder( vehicle ) then 
		end

		checkFct     = function( startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ )
			return AutoSteeringEngine.checkSpecialField( buffer.x, buffer.z, buffer.o, buffer.m, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ )
		end
		areaTotalFct = function( startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ )
			return AutoSteeringEngine.areaTotalSpecial( buffer.x, buffer.z, buffer.o, buffer.m, startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ )
		end

	else
		checkFct     = FieldBitmap.isFieldFast
		areaTotalFct = FieldBitmap.getAreaTotal
	end

	return checkFct, areaTotalFct
end

------------------------------------------------------------------------
-- checkField
------------------------------------------------------------------------
function AutoSteeringEngine.checkField( vehicle, x, z )

	local stepLog2 = ASEGlobals.stepLog2
	local checkFunction, areaTotalFunction = AutoSteeringEngine.getCheckFunction( vehicle )

	if vehicle.aseFieldIsInvalid then
		vehicle.aseChain.lastX = nil
		vehicle.aseChain.lastZ = nil 
	end
	
	if vehicle.aseCurrentField ~= nil then
		if vehicle.aseFieldIsInvalid then
			local x1,_,z1 = localToWorld( vehicle.aseChain.refNode, 0.5 * ( vehicle.aseActiveX + vehicle.aseOtherX ), 0, 0 )
			if vehicle.aseCurrentField.getBit( x1, z1 ) then
				vehicle.aseFieldIsInvalid = false			
			elseif AutoSteeringEngine.checkFieldNoBuffer( x1, z1, checkFunction ) then
				vehicle.aseCurrentField = nil			
			end
		end
	elseif vehicle.aseFieldIsInvalid then
		vehicle.aseCurrentFieldCo = nil
		vehicle.aseCurrentFieldCS = 'dead'
	end
	
	if vehicle.aseCurrentField == nil then
		vehicle.aseFieldIsInvalid = false
		
		local status, hektar = false, 0
		
		if vehicle.aseCurrentFieldCo == nil then
			local x1,_,z1 = getWorldTranslation( vehicle.aseChain.refNode )
			if vehicle.aseChain.lastX ~= nil and vehicle.aseChain.lastZ ~= nil then
				if Utils.vector2LengthSq( vehicle.aseChain.lastX - x1, vehicle.aseChain.lastZ - z1 ) < 1 then
					return true
				else
					vehicle.aseChain.lastX = x1
					vehicle.aseChain.lastZ = z1 
				end
			end
		
			x1,_,z1 = localToWorld( vehicle.aseChain.refNode, 0.5 * ( vehicle.aseActiveX + vehicle.aseOtherX ), 0, 0 )
			local found = AutoSteeringEngine.checkFieldNoBuffer( x1, z1, checkFunction )
			
			if not found then
				local i = 1
				repeat
					if vehicle.aseTools == nil or vehicle.aseTools[i] == nil then
						break
					end
				
					x1,_,z1 = getWorldTranslation( vehicle.aseTools[i].steeringAxleNode )
					found   = AutoSteeringEngine.checkFieldNoBuffer( x1, z1, checkFunction )
					if not found then
						for m=1,table.getn( vehicle.aseTools[i].marker ) do
							x1,_,z1 = getWorldTranslation( vehicle.aseTools[i].marker[m] )
							found   = AutoSteeringEngine.checkFieldNoBuffer( x1, z1, checkFunction )
							if found then break end
						end
					end
					i = i + 1
				until found;
			end
			
			if found then
				if ASEGlobals.yieldCount < 1 then
					if checkFunction == AutoSteeringEngine.checkMowerField then
						vehicle.aseCurrentField, hektar = FieldBitmap.createForFieldAtWorldPosition( x1, z1, stepLog2, 1, areaTotalFunction, nil, nil, 0 )
					else
						vehicle.aseCurrentField, hektar = FieldBitmap.createForFieldAtWorldPositionSimple( x1, z1, stepLog2, 1, checkFunction )
					end
					vehicle.aseCurrentFieldCo = nil
					vehicle.aseCurrentFieldCS = 'dead'
				else
					if checkFunction == AutoSteeringEngine.checkMowerField then
						vehicle.aseCurrentFieldCo = coroutine.create( FieldBitmap.createForFieldAtWorldPosition )
						status, vehicle.aseCurrentField, hektar = coroutine.resume( vehicle.aseCurrentFieldCo, x1, z1, stepLog2, 1, areaTotalFunction, nil, nil, ASEGlobals.yieldCount )
					else
						vehicle.aseCurrentFieldCo = coroutine.create( FieldBitmap.createForFieldAtWorldPositionSimple )
						status, vehicle.aseCurrentField, hektar = coroutine.resume( vehicle.aseCurrentFieldCo, x1, z1, stepLog2, 1, checkFunction, ASEGlobals.yieldCount )
					end
					if status then
						vehicle.aseCurrentFieldCS = coroutine.status( vehicle.aseCurrentFieldCo )
					else
						print("Field detection failed: "..tostring(vehicle.aseCurrentField))
						vehicle.aseCurrentField   = nil
						vehicle.aseCurrentFieldCo = nil
						vehicle.aseCurrentFieldCS = 'dead'
					end
				end
			end
		elseif vehicle.aseCurrentFieldCS ~= 'dead' then
			status, vehicle.aseCurrentField, hektar = coroutine.resume( vehicle.aseCurrentFieldCo )				
			if status then
				vehicle.aseCurrentFieldCS = coroutine.status( vehicle.aseCurrentFieldCo )
			else
				print("Field detection failed: "..tostring(vehicle.aseCurrentField))
				vehicle.aseCurrentField   = nil
				vehicle.aseCurrentFieldCo = nil
				vehicle.aseCurrentFieldCS = 'dead'
			end
		end
		
		if vehicle.aseCurrentFieldCo ~= nil then
			if vehicle.aseCurrentFieldCS == 'dead' then
				vehicle.aseCurrentFieldCo = nil
			else
				g_currentMission:addWarning(string.format("Field detection is running (%0.3f ha)", hektar), 0.018, 0.033);
				if vehicle.aseCurrentField ~= nil then
					print("ups")
					vehicle.aseCurrentField = nil
				end
			end
		end
	end
	
	if vehicle.aseCurrentField == nil then 
		return true --AutoSteeringEngine.checkFieldNoBuffer( x, z, checkFunction ) 
	else
		return vehicle.aseCurrentField.getBit( x, z )
	end
end

------------------------------------------------------------------------
-- isFieldAhead
------------------------------------------------------------------------
function AutoSteeringEngine.isFieldAhead( vehicle, distance, node )
	if node == nil then
		node = vehicle.aseChain.refNode
	end
	
	local w = math.max( 1, 0.25 * vehicle.aseWidth )--+ 0.13 * vehicle.aseHeadland );
	
	for j=-2,2 do
		local x,y,z = localToWorld( node, j * w, 0, distance );
		if AutoSteeringEngine.checkField( vehicle, x, z ) then return true end
	end
	return false
	
end

------------------------------------------------------------------------
-- initHeadlandVector
------------------------------------------------------------------------
function AutoSteeringEngine.initHeadlandVector( vehicle, width )


	if      vehicle.aseChain         ~= nil
	    and vehicle.aseChain.refNode ~= nil then
		local x,_,z = getWorldTranslation( vehicle.aseChain.refNode )
		if     vehicle.aseCollisions == nil
				or vehicle.aseCollisionX == nil
				or vehicle.aseCollisionZ == nil
				or Utils.vector2LengthSq( vehicle.aseCollisionX - x, vehicle.aseCollisionZ - z ) > 2 then
			vehicle.aseCollisions      = {}
			vehicle.aseCollisionX      = x
			vehicle.aseCollisionZ      = z
			vehicle.aseCollisionPoints = nil
		end
	end
	
	if not vehicle.isServer then return end
	
	setRotation( vehicle.aseChain.headlandNode, 0, -AutoSteeringEngine.getTurnAngle( vehicle ), 0 );
	local w;
	if width == nil then
		w           = vehicle.aseWidth;
	else
		w           = width;
	end
	local w       = math.max( 1, 0.25 * w )--+ 0.13 * vehicle.aseHeadland );	
	local d       = 0
	if ASEGlobals.ignoreDist > 0 then
		if d < ASEGlobals.ignoreDist then
			d = ASEGlobals.ignoreDist
		end
		if AutoSteeringEngine.hasTools( vehicle ) then
			for i=1,table.getn(vehicle.aseToolParams) do
				local d2 = math.abs( vehicle.aseToolParams[i].zReal - vehicle.aseToolParams[i].zBack )
				if d < d2 and vehicle.aseTools[vehicle.aseToolParams[i].i].isSowingMachine then 
					d = d2
				end
			end
		end
	end
	d = d + vehicle.aseHeadland
	
	vehicle.aseHeadlandVector       = {}
	vehicle.aseHeadlandVector.front = {}
	vehicle.aseHeadlandVector.back  = {}
	for j=1,5 do
		local front = {}
		front.x,_,front.z   = localDirectionToWorld( vehicle.aseChain.headlandNode, (j-3)*w, 0, d );
		--front.x1,_,front.z1 = localDirectionToWorld( vehicle.aseChain.headlandNode, (j-3)*w, 0, 1 );
		vehicle.aseHeadlandVector.front[j] = front;
		
		local back  = {}
		back.x,_,back.z   = localDirectionToWorld( vehicle.aseChain.headlandNode, (j-3)*w, 0,-d );
		--back.x1,_,back.z1 = localDirectionToWorld( vehicle.aseChain.headlandNode, (j-3)*w, 0, 1 );
		vehicle.aseHeadlandVector.back[j]  = back;
	end
end

------------------------------------------------------------------------
-- isChainPointOnField
------------------------------------------------------------------------
function AutoSteeringEngine.isChainPointOnField( vehicle, xw, zw )
	if not vehicle.isServer then return true end
	
	local front = false;
	local back  = false;

	for j=1,5 do
		if AutoSteeringEngine.checkField( vehicle, xw + vehicle.aseHeadlandVector.front[j].x, zw + vehicle.aseHeadlandVector.front[j].z ) then
			front = true
		end
		if AutoSteeringEngine.checkField( vehicle, xw + vehicle.aseHeadlandVector.back[j].x, zw + vehicle.aseHeadlandVector.back[j].z ) then
			back = true
		end
	end
	
	return front and back;
end

------------------------------------------------------------------------
-- isNotHeadland
------------------------------------------------------------------------
function AutoSteeringEngine.isNotHeadland( vehicle, distance )
	local x,y,z;
	local fRes  = true;
	local angle = AutoSteeringEngine.getTurnAngle( vehicle );
	local dist  = distance;
	
	if vehicle.aseHeadland < 1E-3 then return true end
	
	if math.abs(angle)> 0.5*math.pi then
		dist = -dist;
	end
	
	--if vehicle.aseHeadland > 0 then		
		setRotation( vehicle.aseChain.headlandNode, 0, -angle, 0 );
		
		local d = dist + ( vehicle.aseHeadland + 1 );
		for i=0,d do
			if not AutoSteeringEngine.isFieldAhead( vehicle, d, vehicle.aseChain.headlandNode ) then
				fRes = false;
				break;
			end
		end
		
		if fRes then
			d = dist - ( vehicle.aseHeadland + 1 );
			for i=0,d do
				if not AutoSteeringEngine.isFieldAhead( vehicle, d, vehicle.aseChain.headlandNode ) then
					fRes = false;
					break;
				end
			end
		end
	--end
	
	return fRes;
end

------------------------------------------------------------------------
-- getChainPoint
------------------------------------------------------------------------
function AutoSteeringEngine.getChainPoint( vehicle, i, tp )

	if not vehicle.isServer then return 0,0 end
	
	local invert = false;
	local dx,dz  = 0,0;
	local aRef   = 0;
	local tpx    = tp.x
	local dtpx   = 0;
	
	if i > 1 and ASEGlobals.widthDec ~= 0 then
		dtpx = tp.width * ASEGlobals.widthDec * vehicle.aseChain.length * (i-1)/ASEGlobals.chainMax;
	end
--	if i <= ASEGlobals.widthDec + 1 then
--		dtpx = -tp.offset * ( i - 1 ) / ASEGlobals.widthDec
--	end
	
	if vehicle.aseLRSwitch then
		tpx = tpx - dtpx;
	else
		tpx = tpx + dtpx;
	end
	
	if     vehicle.aseChain.nodes[i].status < ASEStatus.position
      or vehicle.aseChain.nodes[i].tool[tp.i]   == nil 
			or vehicle.aseChain.nodes[i].tool[tp.i].x == nil 
			or vehicle.aseChain.nodes[i].tool[tp.i].z == nil then
			
		if vehicle.aseChain.nodes[i].tool[tp.i] == nil then
			vehicle.aseChain.nodes[i].tool[tp.i] = {};
		end

		if math.abs( tp.b2 ) > 1E-4 then
			for j=1,i do
				if vehicle.aseChain.nodes[j].tool[tp.i].a == nil then
					if math.abs( vehicle.aseChain.nodes[j].steering ) < 1E-5 then
						vehicle.aseChain.nodes[j].tool[tp.i].a = 0;
					else
						local rr = math.sqrt( math.abs( vehicle.aseChain.nodes[j].radius * vehicle.aseChain.nodes[j].radius + tp.b1 * tp.b1 - tp.b2 * tp.b2 ) );
						local aa = math.atan( tp.b2 / rr ) + math.atan( tp.b1 / math.abs(vehicle.aseChain.nodes[j].radius) );
						if vehicle.aseChain.nodes[j].radius > 0 then aa = -aa end
						vehicle.aseChain.nodes[j].tool[tp.i].a = aa;
					end
				end
			end
		end
		
		if vehicle.aseLRSwitch ~= nil and tp.b1 < 0 then
			if math.abs( tp.b2 ) > 1E-3 then
				local a=0;
				for j=1,ASEGlobals.offtracking do
					jj = i - j;
					if jj < 1 then
						a = a + tp.angle;
					else
						a = a + vehicle.aseChain.nodes[jj].tool[tp.i].a;
					end
				end
				a = a / ASEGlobals.offtracking;

				setRotation(    vehicle.aseChain.tNode[1], 0, -a, 0 );
				setTranslation( vehicle.aseChain.tNode[1], 0, 0, tp.b1 );
				setTranslation( vehicle.aseChain.tNode[2], tpx, 0, tp.z-tp.b1 );
				local xt,_,zt = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.tNode[0], vehicle.aseChain.tNode[2] );
			
				dx = tpx - xt;
				dz = zt - tp.z;
			elseif i > 1 then
				if i == 1 then
					aRef = vehicle.aseSteeringAngle;
				else
					aRef = vehicle.aseChain.nodes[i-1].steering;
				end
			
				if math.abs(aRef) > 1E-5 then
					if ( vehicle.aseLRSwitch and aRef > 0 ) or ( ( not vehicle.aseLRSwitch ) and aRef < 0 ) then
						invert = false;
					else
						invert = true;
					end
				
					local r  = vehicle.aseChain.wheelBase / math.tan( math.abs(aRef) );
					local r1 = math.sqrt( r*r + tp.b1*tp.b1 );
				
					if invert then
						r = r + tpx;
					else
						r = r - tpx;
					end			
					dx = math.sqrt( r*r + tp.b1*tp.b1 ) - r;		
				end
				
				if invert then dx = -dx end
			end	
		end
		
		if     vehicle.aseLRSwitch and dx > 0 then dx = math.max(0,dx-tp.offset) end
		if not vehicle.aseLRSwitch and dx < 0 then dx = math.min(0,dx+tp.offset) end
		
		vehicle.aseChain.nodes[i].status = ASEStatus.position;
		vehicle.aseChain.nodes[i].tool[tp.i].x = tpx - dx;
		vehicle.aseChain.nodes[i].tool[tp.i].z = tp.z + dz;
	end
	
	return vehicle.aseChain.nodes[i].tool[tp.i].x, vehicle.aseChain.nodes[i].tool[tp.i].z;
	
end

------------------------------------------------------------------------
-- getChainBorder
------------------------------------------------------------------------
function AutoSteeringEngine.getChainBorder( vehicle, i1, i2, toolParam, noBreak )
	if not vehicle.isServer then return 0,0 end
	
	local b,t    = 0,0;
	local bo,to  = 0,0;
	local i      = i1;
	local count  = 0;
	local offsetOutside = -1;
	
	if vehicle.aseLRSwitch	then
		offsetOutside = 1
	end

	local fcOffset = -offsetOutside * toolParam.width;
	local detectedBefore = false
	
	if 1 <= i and i <= ASEGlobals.chainMax then
		local x,z     = AutoSteeringEngine.getChainPoint( vehicle, i, toolParam );
		local xp,yp,zp = localToWorld( vehicle.aseChain.nodes[i].index,   x, 0, z );
		
		while i<=i2 and i<=ASEGlobals.chainMax do				
			x,z = AutoSteeringEngine.getChainPoint( vehicle, i+1, toolParam );
			local xc,yc,zc = localToWorld( vehicle.aseChain.nodes[i+1].index, x, 0, z );
						
			local fRes = not AutoSteeringEngine.hasCollision( vehicle, vehicle.aseChain.nodes[i].index )
			         and not AutoSteeringEngine.hasCollision( vehicle, vehicle.aseChain.nodes[i+1].index )
			         and AutoSteeringEngine.isChainPointOnField( vehicle, xp, zp ) 
							 and AutoSteeringEngine.isChainPointOnField( vehicle, xc, zc )
			
			--if      fRes 
			--		and ( vehicle.aseTools[toolParam.i].isMower 
			--			 or ( vehicle.aseTools[toolParam.i].isCombine 
			--				and vehicle.aseTools[toolParam.i].obj.lastValidInputFruitType == FruitUtil.FRUITTYPE_GRASS ) ) then
			--	local bi, ti  = AutoSteeringEngine.getFruitArea( xp, zp, xc, zc, fcOffset, vehicle.aseTools[toolParam.i] )				
			--	if bi > 0 then
			--		detectedBefore = true
			--	elseif detectedBefore then
			--		break
			--	end
			--end
			
			if fRes then
				vehicle.aseChain.nodes[i].isField = true
				count = count + 1
				local bi, ti  = AutoSteeringEngine.getFruitArea( vehicle, xp, zp, xc, zc, offsetOutside, toolParam.i )			

				b = b + bi;
				t = t + ti;
			end
			
			if b > 1 then 
				if noBreak then
				else
					break 
				end
			end
			
			i = i + 1;
			xp = xc;
			yp = yc;
			zp = zc;
		end
	end
	
	return b, t, bo, to;
end

------------------------------------------------------------------------
-- getAllChainBorders
------------------------------------------------------------------------
function AutoSteeringEngine.getAllChainBorders( vehicle, i1, i2, noBreak )
	if not vehicle.isServer then return 0,0 end
	
	local b,t,bo,to = 0,0,0,0;
	
	if i1 == nil then i1 = 1 end
	if i2 == nil then i2 = ASEGlobals.chainMax end
	
	for _,tp in pairs(vehicle.aseToolParams) do	
		if tp.skip then
			--nothing
		else
			local bi,ti,boi,toi = AutoSteeringEngine.getChainBorder( vehicle, i1, i2, tp );				
			b  = b  + bi;
			t  = t  + ti;
			bo = bo + boi;
			to = to + toi;
		end
	end
	
	if to > 0 then
		b = b + bo / to;
	  t = t + 1;
	end
	
	return b,t;
end

------------------------------------------------------------------------
-- getSteeringParameterOfTool
------------------------------------------------------------------------
function AutoSteeringEngine.getSteeringParameterOfTool( vehicle, toolIndex, maxLooking, widthOffset )
	
	local toolParam = {}
	toolParam.i       = toolIndex;

	local tool = vehicle.aseTools[toolIndex];
	local maxAngle, minAngle;
	local xl = -999;
	local xr = 999;
	local zb = 999;
	local il, ir, ib, i1, zl, zr;	
	
	if tool.aiForceTurnNoBackward then
	
--  no reverse allowed	
		local xOffset,_,zOffset = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode, tool.refNode );
		if tool.aiBackMarker ~= nil then
			_,_,zb = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode, tool.aiBackMarker );
			zb = zb - zOffset;
		end
		
		for i=1,table.getn(tool.marker) do
			local xxx,_,zzz = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode, tool.marker[i] );
			xxx = xxx - xOffset;
			zzz = zzz - zOffset;
			if tool.invert then xxx = -xxx; zzz = -zzz end
			if xl < xxx then xl = xxx; zl = zzz; il = i end
			if xr > xxx then xr = xxx; zr = zzz; ir = i end
			-- back marker!
			if zb > zzz then zb = zzz; ib = i end
		end
		
		local width  = xl - xr;		
		local offset = AutoSteeringEngine.getWidthOffset( vehicle, width, widthOffset );

		width = width - offset - offset;

		if vehicle.aseLRSwitch	then
	-- left	
			x0 = xl - offset;
			z0 = zl;
			i1 = il;
		else
	-- right	
			x0 = xr + offset;
			z0 = zr;
			i1 = ir;
		end
		
		local x1,_,z1 = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, tool.refNode );
		
		x1 = x1 + x0;
		z1 = z1 + z0;
		toolParam.zReal = z1;
		
		local b1,b2 = z1, 0;

		local r1 = math.sqrt( x1*x1 + b1*b1 );		
		r1       = ( 1 + ASEGlobals.minMidDist ) * ( r1 + math.max( 0, -b1 ) );
		local a1 = math.atan( vehicle.aseChain.wheelBase / r1 );
		--local a2 = maxAngle; --math.atan( 2 * vehicle.aseChain.wheelBase / width );
		if vehicle.aseLRSwitch then
			minAngle = -maxLooking; --vehicle.aseChain.maxSteering; -- -math.min(a2,maxAngle);
			maxAngle = math.min(a1,maxLooking);
		else
			minAngle = -math.min(a1,maxLooking);
			maxAngle = maxLooking; --vehicle.aseChain.maxSteering; -- math.min(a2,maxAngle);
		end
		
		local toolAngle = 0;
	
		if b1 < 0 then
			local _,_,z4  = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, tool.refNode );
			b1 = z4; -- + 0.4;
			
			if tool.b1 ~= nil then
				b1 = b1 + tool.b1;
			end
			
			if tool.b2 == nil then
				local x3,_,z3 = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode ,tool.marker[i1] );
				if tool.invert then x3 = -x3; z3=-z3 end				
				local _,_,z5  = AutoSteeringEngine.getRelativeTranslation( tool.marker[i1] ,tool.aiBackMarker );
				if tool.invert then z5=-z5 end								
				b2 = z3 - zOffset + 0.5 * z5;
			else
				b2 = tool.b2
			end
			
			if b1 < 0 and b2 < -1 then
				b2 = b2 + 0.5
				b1 = b1 - 0.5
			end
			
			toolAngle = AutoSteeringEngine.getRelativeYRotation( vehicle.aseChain.refNode, tool.steeringAxleNode );
			if tool.invert then
				if toolAngle < 0 then
					toolAngle = toolAngle + math.pi
				else
					toolAngle = toolAngle - math.pi
				end
			end

			z1 = 0.5 * ( b1 + z1 );
		end

		toolParam.x        = x1;
		toolParam.z        = z1;
		toolParam.zBack    = zb;
		toolParam.nodeBack = tool.marker[ib];
		toolParam.nodeLeft = tool.marker[il];
		toolParam.nodeRight= tool.marker[ir];
		toolParam.minAngle = minAngle;
		toolParam.maxAngle = maxAngle;
		toolParam.b1       = b1;
		toolParam.b2       = b2;
		toolParam.offset   = offset;
		toolParam.width    = width;
		toolParam.angle    = toolAngle;

	else
		local x1
		local z1 = -999
	
--  normal tool, can be lifted and reverse is possible
		if tool.aiBackMarker ~= nil then
			_,_,zb = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, tool.aiBackMarker );
		end
		
		for i=1,table.getn(tool.marker) do
			local xxx,_,zzz = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, tool.marker[i] );
			if xl < xxx then xl = xxx; il = i end
			if xr > xxx then xr = xxx; ir = i end
			if z1 < zzz then z1 = zzz end
			-- back marker!
			if zb > zzz then zb = zzz; ib = i end
		end

		local width  = xl - xr;
		local offset = AutoSteeringEngine.getWidthOffset( vehicle, width, widthOffset );

		width = width - offset - offset;

		if vehicle.aseLRSwitch	then
	-- left	
			x1 = xl - offset;
			i1 = il;
		else
	-- right	
			x1 = xr + offset;
			i1 = ir;
		end

		toolParam.zReal = z1;

		local r1 = math.sqrt( x1*x1 + z1*z1 );		
		r1       = ( 1 + ASEGlobals.minMidDist ) * ( r1 + math.max( 0, -z1 ) );
		local a1 = math.atan( vehicle.aseChain.wheelBase / r1 );
		
		--if tool.isPlough then
			--a1 = 0.5 * a1;
		--elseif z1 < 0 and vehicle.aseSteeringAngle ~= nil then			
		if z1 < 0 and vehicle.aseSteeringAngle ~= nil then			
			if math.abs( vehicle.aseSteeringAngle ) > 1E-4 then
				local rr, xx, bb;
				if vehicle.aseSteeringAngle > 0 then
					xx = x1;
				else
					xx = -x1;
				end				
				rr = vehicle.aseChain.wheelBase / math.tan( math.abs( vehicle.aseSteeringAngle ) );
				if 0 < xx and xx < rr then
					bb = math.atan( -z1 / ( rr - xx ) );
				else
					bb = math.asin( -z1 / rr );
				end
								
				xx = rr * ( 1 - math.cos( bb ) );
				if vehicle.aseSteeringAngle > 0 then
					x1 = x1 + xx;
				else
					x1 = x1 - xx;
				end
				z1 = z1 + rr * math.sin( bb ); 
			else
				z1 = 0;
			end
		end

		if vehicle.aseLRSwitch then
			minAngle = -maxLooking; --vehicle.aseChain.maxSteering; -- -maxAngle;
			maxAngle = math.min(a1,maxLooking);
		else
			minAngle = -math.min(a1,maxLooking);
			maxAngle = maxLooking; --vehicle.aseChain.maxSteering;
		end
		
		toolParam.x        = x1;
		toolParam.z        = z1;
		toolParam.zBack    = zb;
		toolParam.nodeBack = tool.marker[ib];
		toolParam.nodeLeft = tool.marker[il];
		toolParam.nodeRight= tool.marker[ir];
		toolParam.minAngle = minAngle;
		toolParam.maxAngle = maxAngle;
		toolParam.b1       = z1;
		toolParam.b2       = 0;
		toolParam.offset   = offset;
		toolParam.width    = width;
		toolParam.angle    = 0;
	
	end
		
	return toolParam;
end

------------------------------------------------------------------------
-- setChainStatus
------------------------------------------------------------------------
function AutoSteeringEngine.setChainStatus( vehicle, startIndex, newStatus )
	if not vehicle.isServer then return end
	
	if vehicle.aseChain ~= nil and vehicle.aseChain.nodes ~= nil then
		local i = math.max(startIndex,1);
		while i <= ASEGlobals.chainMax + 1 do
			if vehicle.aseChain.nodes[i].status > newStatus then
				vehicle.aseChain.nodes[i].status = newStatus
			end
			i = i + 1;
		end
	end
end

------------------------------------------------------------------------
-- initSteering
------------------------------------------------------------------------
function AutoSteeringEngine.initSteering( vehicle, savedMarker, uTurn )

	local mi = vehicle.aseMinAngle; 
	local ma = vehicle.aseMaxAngle;

	if vehicle.aseToolParams == nil or table.getn( vehicle.aseToolParams ) < 1 then
		vehicle.aseMinAngle = -vehicle.aseChain.maxSteering;
		vehicle.aseMaxAngle = vehicle.aseChain.maxSteering;
		vehicle.aseWidth    = 0;
		vehicle.aseDistance = 0;
		vehicle.aseActiveX  = 0;
		vehicle.aseOtherX   = 0;
		vehicle.aseOffset   = 0;
		vehicle.aseBack     = 0;
  else
		vehicle.aseMinAngle = nil;
		vehicle.aseMaxAngle = nil;
		vehicle.aseWidth    = nil;
		vehicle.aseDistance = nil;
		vehicle.aseActiveX  = nil;
		vehicle.aseOtherX   = nil;
		vehicle.aseOffset   = nil;
		vehicle.aseBack     = nil; 
		
		for _,tp in pairs(vehicle.aseToolParams) do				
			if vehicle.aseMinAngle == nil or vehicle.aseMinAngle > tp.minAngle then
				vehicle.aseMinAngle = tp.minAngle
			end
			if vehicle.aseMaxAngle == nil or vehicle.aseMaxAngle < tp.maxAngle then
				vehicle.aseMaxAngle = tp.maxAngle
			end
			if vehicle.aseDistance  == nil or vehicle.aseDistance  > tp.zReal then
				vehicle.aseDistance  = tp.zReal;
			end
			if vehicle.aseOffset == nil or vehicle.aseOffset < tp.offset then
				vehicle.aseOffset = tp.offset
			end
			local z = 0
			if vehicle.aseTools[tp.i].isPlough then
				z = math.min( tp.zReal, tp.zBack + 2 )
			end
			if vehicle.aseBack == nil or vehicle.aseBack > z then
				vehicle.aseBack = z
			end
			
			if tp.skip then
				--nothing
			else
				local ax, ox, oi, wi
				local left = vehicle.aseLRSwitch
				if savedMarker and vehicle.aseTools[tp.i].savedAx ~= nil then
					if uTurn and AITractor.invertsMarkerOnTurn(vehicle, left) then
						ax = -vehicle.aseTools[tp.i].savedOx
						ox = -vehicle.aseTools[tp.i].savedAx					
					else
						ax = vehicle.aseTools[tp.i].savedAx
						ox = vehicle.aseTools[tp.i].savedOx					
					end
					oi = vehicle.aseTools[tp.i].savedOi			
					wi = vehicle.aseTools[tp.i].savedWi			
				else
					wi = tp.width
					if left then
						ax = tp.x -- - 0.2;
						ox = tp.x - tp.width -- + 0.2;
						oi = tp.nodeRight;
					else
						ax = tp.x -- + 0.2;
						ox = tp.width + tp.x -- - 0.2;
						oi =  tp.nodeLeft
					end
					vehicle.aseTools[tp.i].savedAx = ax
					vehicle.aseTools[tp.i].savedOx = ox
					vehicle.aseTools[tp.i].savedOi = oi
					vehicle.aseTools[tp.i].savedWi = wi
				end
				
				if vehicle.aseWidth == nil or vehicle.aseWidth > tp.width then
					vehicle.aseWidth = wi
				end
				if vehicle.aseLRSwitch	then
					if vehicle.aseActiveX  == nil or vehicle.aseActiveX > ax then
						vehicle.aseActiveX = ax;
					end
					if vehicle.aseOtherX  == nil or vehicle.aseOtherX   < ox then
						vehicle.aseOtherX  = ox 
						vehicle.aseOtherI  = oi
					end
				else
					if vehicle.aseActiveX  == nil or vehicle.aseActiveX < ax then
						vehicle.aseActiveX = ax;
					end
					if vehicle.aseOtherX  == nil or vehicle.aseOtherX   > ox then
						vehicle.aseOtherX  = ox;
						vehicle.aseOtherI  = oi;
					end
				end
			end
		end
  end
	
	if not vehicle.aseLRSwitch then vehicle.aseOffset = -vehicle.aseOffset end
	
	vehicle.aseAngleFactor = AutoSteeringEngine.getAngleFactor( math.max( math.abs( vehicle.aseMinAngle ), math.abs( vehicle.aseMaxAngle ) ) );
	if not vehicle.aseLRSwitch	then
		vehicle.aseAngleFactor = -vehicle.aseAngleFactor
	end 
	
	if mi == nil or ma == nil or math.abs( vehicle.aseMinAngle - mi ) > 1E-4 or math.abs( vehicle.aseMaxAngle - ma ) > 1E-4 then
		AutoSteeringEngine.setChainStatus( vehicle, 1, ASEStatus.initial );	
		AutoSteeringEngine.applyRotation( vehicle );		
	end

	AutoSteeringEngine.initHeadlandVector( vehicle, vehicle.aseWidth )	

	if vehicle.aseChain ~= nil and vehicle.aseChain.nodes ~= nil then
		for i=1,ASEGlobals.chainMax do	
			vehicle.aseChain.nodes[i].isField = false;
		end	
	end	
end

------------------------------------------------------------------------
-- processChain
------------------------------------------------------------------------
function AutoSteeringEngine.processChain( vehicle )
	
	if not vehicle.isServer then return false,0,0 end
	
	local detected  = false;
	
	local indexMax = ASEGlobals.chainMax 
	
	if vehicle.aseToolParams == nil or table.getn( vehicle.aseToolParams ) < 1 then
		return false, 0,0;
	end
	
	AutoSteeringEngine.initSteering( vehicle )	

	local border, total = 0,0;
	local i = 1;
	local foundNothing = false;
	local delta0 = -ASEGlobals.angleMax / ASEGlobals.chainDivide;
	
	for step0=1,ASEGlobals.chainRefine do
		
		for i=1,indexMax do 
			border, total  = AutoSteeringEngine.getAllChainBorders( vehicle, i, indexMax );
			
			if i == 1 then
				delta = ASEGlobals.chainFactor1 * delta0 
			else
				delta  = delta0
			end
			
			for step=1,2 do
				local doit = false;
				
				if border <= 0 then
					if delta < 0 then
						doit = true;
					end
				else
					detected = true;
					if delta > 0 then
						doit = true;
					end
				end
				
				while doit do				
					doit = false;
					
					local old1 = vehicle.aseChain.nodes[i].angle;		
					vehicle.aseChain.nodes[i].angle = math.min( math.max( vehicle.aseChain.nodes[i].angle + delta, -ASEGlobals.angleMax ), ASEGlobals.angleMax );
					
					if old1 ~= vehicle.aseChain.nodes[i].angle then 
						AutoSteeringEngine.setChainStatus( vehicle, i, ASEStatus.initial );
						AutoSteeringEngine.applyRotation( vehicle );				
						border, total  = AutoSteeringEngine.getAllChainBorders( vehicle, i, indexMax );
					
						if border <= 0 then
							if delta < 0 then
								doit = true;
							end
						else
							detected = true;
							if delta > 0 then
								doit = true;
							end
						end
					end
				end
				
				delta = -delta				
			end
		end

		delta0 = delta0 / ASEGlobals.chainDivide;
	end
	
	border, total  = AutoSteeringEngine.getAllChainBorders( vehicle, 1, indexMax, true );	
	
	local avg = nil
	for i=1,indexMax do 
		if vehicle.aseChain.nodes[i].isField then
			avg = i
			break
		end
	end
	
	if avg == nil then 
		return false, 0, 0
	end
	
	local avgMin = 1;
	if AutoSteeringEngine.getNoReverseIndex( vehicle ) > 0 or not AutoSteeringEngine.noTurnAtEnd( vehicle ) then
		while avgMin < ASEGlobals.chainMax and vehicle.aseChain.nodes[avgMin].distance < -vehicle.aseDistance do
			avgMin = avgMin + 1;
		end
	end
	
	avg = avgMin;
	
	while avg > avgMin + 1 and not vehicle.aseChain.nodes[avg].isField do
		avg = avg - 1
	end
	avg = avg - 1
	if detected and avg == 1 then
		while avg < indexMax and not vehicle.aseChain.nodes[avg].isField do
			avg = avg + 1
		end
	end
	
	--renderText(0.5, 0.5, 0.1, tostring(avg));
	
	if detected and border > 0 and avg > 1 then
		border, total  = AutoSteeringEngine.getAllChainBorders( vehicle, avg, indexMax );
	end 
	if detected and border > 0 then
		detected = false;
	end
	
	if indexMax < ASEGlobals.chainMax then
		AutoSteeringEngine.setChainStraight( vehicle, indexMax + 1 );
	end
	
	if ASEGlobals.zeroAngle > 0 then
		af = vehicle.aseMaxAngle / ASEGlobals.angleMax
		if not vehicle.aseLRSwitch	then
			af = -af
		end 
	else
		af = vehicle.aseAngleFactor
	end	
	local angle = math.min( math.max( vehicle.aseSteeringAngle + af * vehicle.aseChain.nodes[1].angle, vehicle.aseMinAngle ), vehicle.aseMaxAngle );
	
	if avg > 1 then
		local xw1,yw1,zw1 = localToWorld( vehicle.aseChain.nodes[1].index,0,0,0 );
		local xw2,yw2,zw2 = localToWorld( vehicle.aseChain.nodes[avg].index,0,0,0 );
		
		local dirx,_,dirz = worldDirectionToLocal( vehicle.aseChain.refNode, xw2-xw1, yw2-yw1, zw2-zw1 );
		--local l = math.sqrt( dirx*dirx + dirz*dirz );
		--if l < 1E-3 then
		--	angle = 0 
		--else
		--	angle = math.acos( dirz / l );
		--	if dirx < 0 then angle = -angle end;
		--	angle = math.atan( math.min( math.max( angle * vehicle.aseChain.wheelBase, -0.25*math.pi ), 0.25*math.pi ) );
		--	angle = math.min( math.max( angle, vehicle.aseMinAngle ), vehicle.aseMaxAngle );
		--end
		local d = dirx*dirx + dirz*dirz
		if d < 1E-3 then
			angle = 0
		else
			angle = math.atan( 2 * dirx * vehicle.aseChain.wheelBase / d )
			angle = math.min( math.max( angle, vehicle.aseMinAngle ), vehicle.aseMaxAngle )
		end
	end
	
	return detected, angle, border;
end

------------------------------------------------------------------------
-- setChainStraight
------------------------------------------------------------------------
function AutoSteeringEngine.setChainStraight( vehicle, startIndex, startAngle )	
	if vehicle.aseChain == nil or vehicle.aseChain.nodes == nil then
		return
	end
	local j0=1;
	if startIndex ~= nil and 1 < startIndex and startIndex <= ASEGlobals.chainMax+1 then
		j0 = startIndex;
	end
	local a  = vehicle.aseSteeringAngle;
	if a == nil then a = 0 end;
	local af = AutoSteeringEngine.getAngleFactor( );

	for j=1,ASEGlobals.chainMax+1 do 
		local old = vehicle.aseChain.nodes[j].angle;
		if     j==j0 and startAngle ~= nil then
			vehicle.aseChain.nodes[j].angle = startAngle;
		elseif j>=j0 then
			vehicle.aseChain.nodes[j].angle = math.min( math.max( -a/af , -ASEGlobals.angleMax ), ASEGlobals.angleMax );
		end
		if math.abs( vehicle.aseChain.nodes[j].angle - old ) > 1E-5 then
			AutoSteeringEngine.setChainStatus( vehicle, j, ASEStatus.initial );
		end
		local b = a + af * vehicle.aseChain.nodes[j].angle;
		a = math.min( math.max( b, vehicle.aseMinAngle ), vehicle.aseMaxAngle );
	end 
	AutoSteeringEngine.applyRotation( vehicle );			

	local angle = vehicle.aseSteeringAngle + af * vehicle.aseChain.nodes[1].angle;
	return angle;
end

------------------------------------------------------------------------
-- setChainOutside
------------------------------------------------------------------------
function AutoSteeringEngine.setChainOutside( vehicle, startIndex, angleSafety )
	local j0=1;
	if startIndex ~= nil and 1 < startIndex and startIndex <= ASEGlobals.chainMax+1 then
		j0 = startIndex;
	end
	if angleSafety == nil then
		angleSafety = ASEGlobals.angleSafety
	end
	for j=j0,ASEGlobals.chainMax+1 do 
		local old = vehicle.aseChain.nodes[j].angle;
		if AutoSteeringEngine.isNotHeadland( vehicle, vehicle.aseChain.nodes[j].distance ) then
			vehicle.aseChain.nodes[j].angle = angleSafety * ASEGlobals.angleMax;
		else
			vehicle.aseChain.nodes[j].angle = 0
		end
		if math.abs( vehicle.aseChain.nodes[j].angle - old ) > 1E-5 then
			AutoSteeringEngine.setChainStatus( vehicle, j, ASEStatus.initial );
		end
	end 
	AutoSteeringEngine.applyRotation( vehicle );			
end

------------------------------------------------------------------------
-- setChainContinued
------------------------------------------------------------------------
function AutoSteeringEngine.setChainContinued( vehicle, startIndex )
	local j0=1;
	if startIndex ~= nil and 1 < startIndex and startIndex <= ASEGlobals.chainMax+1 then
		j0 = startIndex;
	end
	for j=j0,ASEGlobals.chainMax+1 do 
		local old = vehicle.aseChain.nodes[j].angle;
		if math.abs( vehicle.aseChain.nodes[j].angle ) > 1E-5 then
			AutoSteeringEngine.setChainStatus( vehicle, j, ASEStatus.initial );
		end
		vehicle.aseChain.nodes[j].angle = 0;
	end 
	AutoSteeringEngine.applyRotation( vehicle );			
end

------------------------------------------------------------------------
-- setChainInside
------------------------------------------------------------------------
function AutoSteeringEngine.setChainInside( vehicle, startIndex )
	local j0=1;
	if startIndex ~= nil and 1 < startIndex and startIndex <= ASEGlobals.chainMax+1 then
		j0 = startIndex;
	end
	a = vehicle.aseSteeringAngle;
	if a == nil then a = 0 end;
	for j=j0,ASEGlobals.chainMax+1 do 
		local old = vehicle.aseChain.nodes[j].angle;
		vehicle.aseChain.nodes[j].angle = -ASEGlobals.angleSafety * ASEGlobals.angleMax;
		if math.abs( vehicle.aseChain.nodes[j].angle - old ) > 1E-5 then
			AutoSteeringEngine.setChainStatus( vehicle, j, ASEStatus.initial );
		end
	end 
	AutoSteeringEngine.applyRotation( vehicle );			
end

------------------------------------------------------------------------
-- getParallelogram
------------------------------------------------------------------------
function AutoSteeringEngine.getParallelogram( xs, zs, xh, zh, diff, noMinLength )
	local xw, zw, xd, zd;
	
	xd = zh - zs;
	zd = xs - xh;
	
	local l = math.sqrt( xd*xd + zd*zd );
	
	if l < 1E-3 then
		xw = xs;
		zw = zs;
	elseif noMinLength then
	elseif l < ASEGlobals.minLength then
		local f = ASEGlobals.minLength / l;
		local x2 = xh - xs;
		local z2 = zh - zs;
		--xs = xs - f * x2;
		--zs = zs - f * z2;
		xh = xh + f * x2;
		zh = zh + f * z2;
		xd = zh - zs;
		zd = xs - xh;
		l  = math.sqrt( xd*xd + zd*zd );
	end
	
	if 0.999 < l and l < 1.001 then
		xw = xs + diff * xd;
		zw = zs + diff * zd;
	elseif l > 1E-3 then
		xw = xs + diff * xd / l;
		zw = zs + diff * zd / l;
	else
		xw = xs;
		zw = zs;
	end
	
	return xs, zs, xw, zw, xh, zh;
end

function AutoSteeringEngine.clearTrace( vehicle )
	vehicle.aseDirectionBeforeTurn = {};
end

------------------------------------------------------------------------
-- saveDirection
------------------------------------------------------------------------
function AutoSteeringEngine.saveDirection( vehicle, cumulate, fruits )

	if vehicle.aseDirectionBeforeTurn == nil then
		vehicle.aseDirectionBeforeTurn = {};
	end
	
	if cumulate then
		local vector = {};	
		vector.dx,_,vector.dz = localDirectionToWorld( vehicle.aseChain.refNode, 0,0,1 );
		vector.px,_,vector.pz = getWorldTranslation( vehicle.aseChain.refNode );
		
		if vehicle.aseDirectionBeforeTurn.traceIndex == nil then
			vehicle.aseDirectionBeforeTurn.trace = {};
			vehicle.aseDirectionBeforeTurn.traceIndex = 0;
		end;
		
		local count = table.getn(vehicle.aseDirectionBeforeTurn.trace);
		if count > 100 and vehicle.aseDirectionBeforeTurn.traceIndex == count then
			local x = vehicle.aseDirectionBeforeTurn.trace[vehicle.aseDirectionBeforeTurn.traceIndex].px - vehicle.aseDirectionBeforeTurn.trace[1].px;
			local z = vehicle.aseDirectionBeforeTurn.trace[vehicle.aseDirectionBeforeTurn.traceIndex].pz - vehicle.aseDirectionBeforeTurn.trace[1].pz;		
		
			if x*x + z*z > 36 then 
				vehicle.aseDirectionBeforeTurn.traceIndex = 0
			end
		end;
		vehicle.aseDirectionBeforeTurn.traceIndex = vehicle.aseDirectionBeforeTurn.traceIndex + 1;
		
		vehicle.aseDirectionBeforeTurn.trace[vehicle.aseDirectionBeforeTurn.traceIndex] = vector;
		vehicle.aseDirectionBeforeTurn.a = nil;
		vehicle.aseDirectionBeforeTurn.xOffset = nil
		vehicle.aseDirectionBeforeTurn.targetTrace = nil
		vehicle.aseDirectionBeforeTurn.x ,_,vehicle.aseDirectionBeforeTurn.z  = localToWorld( vehicle.aseOtherI, vehicle.aseOffset, 0, vehicle.aseBack ); 
	else
		vehicle.aseDirectionBeforeTurn.trace = {};
		vehicle.aseDirectionBeforeTurn.traceIndex = 0;
		vehicle.aseDirectionBeforeTurn.sx, _, vehicle.aseDirectionBeforeTurn.sz = getWorldTranslation( vehicle.aseChain.refNode );
	end
end

------------------------------------------------------------------------
-- getFirstTraceIndex
------------------------------------------------------------------------
function AutoSteeringEngine.getFirstTraceIndex( vehicle )
	if     vehicle.aseDirectionBeforeTurn.trace      == nil 
			or vehicle.aseDirectionBeforeTurn.traceIndex == nil 
			or vehicle.aseDirectionBeforeTurn.traceIndex < 1 then
		return nil;
	end;
	local l = table.getn(vehicle.aseDirectionBeforeTurn.trace);
	if l < 1 then
		return nil;
	end;
	local i = vehicle.aseDirectionBeforeTurn.traceIndex + 1;
	if i > l then i = 1 end
	return i;
end

------------------------------------------------------------------------
-- getTurnVector
------------------------------------------------------------------------
function AutoSteeringEngine.getTurnVector( vehicle, uTurn )
	if     vehicle.aseChain.refNode         == nil
			or vehicle.aseDirectionBeforeTurn   == nil
			or vehicle.aseDirectionBeforeTurn.x == nil
			or vehicle.aseDirectionBeforeTurn.z == nil then
		return 0,0;
	end;

	if vehicle.aseDirectionBeforeTurn.xOffset == nil then	
		AutoSteeringEngine.initTurnVector( vehicle, uTurn )
	end
	
	setRotation( vehicle.aseChain.headlandNode, 0, -AutoSteeringEngine.getTurnAngle( vehicle ), 0 );
	
	local _,y,_ = getWorldTranslation( vehicle.aseChain.refNode );
	local x,_,z = worldToLocal( vehicle.aseChain.headlandNode, vehicle.aseDirectionBeforeTurn.x , y, vehicle.aseDirectionBeforeTurn.z );
	
	if uTurn then
		z = z
		x = x + vehicle.aseActiveX
	else
		x = x
		if vehicle.aseLRSwitch then
			z = z - vehicle.aseActiveX
		else
			z = z + vehicle.aseActiveX
		end
	end
	
	-- change view point...
	x = -x
	z = -z
	
	return x,z
end

------------------------------------------------------------------------
-- initTurnVector
------------------------------------------------------------------------
function AutoSteeringEngine.initTurnVector( vehicle, uTurn )
	
	if     vehicle.aseChain.refNode         == nil
			or vehicle.aseDirectionBeforeTurn   == nil
			or vehicle.aseDirectionBeforeTurn.x == nil
			or vehicle.aseDirectionBeforeTurn.z == nil then
		return
	end;
		
	setRotation( vehicle.aseChain.headlandNode, 0, -AutoSteeringEngine.getTurnAngle( vehicle ), 0 );
	
	if vehicle.aseDirectionBeforeTurn.a == nil then return end
		
	vehicle.aseDirectionBeforeTurn.xOffset = 0
	vehicle.aseDirectionBeforeTurn.zOffset = 0
		
	if vehicle.aseTools ~= nil and table.getn( vehicle.aseTools ) > 0 then	
		local dxz, _,dzz  = localDirectionToWorld( vehicle.aseChain.headlandNode, 0, 0, 1 )
		local dxx, _,dzx  = localDirectionToWorld( vehicle.aseChain.headlandNode, 1, 0, 0 )			
		local xw1,zw1,xw2,zw2 
		
		xw1 = vehicle.aseDirectionBeforeTurn.x - 5 * dxz
		zw1 = vehicle.aseDirectionBeforeTurn.z - 5 * dzz
		xw2 = vehicle.aseDirectionBeforeTurn.x
		zw2 = vehicle.aseDirectionBeforeTurn.z
		
		if AutoSteeringEngine.hasFruitsSimple( vehicle, xw1, zw1, xw2, zw2, 1 ) and AutoSteeringEngine.hasFruitsSimple( vehicle, xw1, zw1, xw2, zw2, -1 ) then
			for i = 1,20 do
				if  AutoSteeringEngine.hasFruitsSimple( vehicle, xw1+0.1*i*dxx, zw1+0.1*i*dzx, xw2+0.1*i*dxx, zw2+0.1*i*dzx, 1 ) ~=
						AutoSteeringEngine.hasFruitsSimple( vehicle, xw1+0.1*i*dxx, zw1+0.1*i*dzx, xw2+0.1*i*dxx, zw2+0.1*i*dzx, -1 ) then						
					vehicle.aseDirectionBeforeTurn.xOffset = 0.1*i
					vehicle.aseDirectionBeforeTurn.x = vehicle.aseDirectionBeforeTurn.x+0.1*i*dxx
					vehicle.aseDirectionBeforeTurn.z = vehicle.aseDirectionBeforeTurn.z+0.1*i*dzx
					break;
				end
				if  AutoSteeringEngine.hasFruitsSimple( vehicle, xw1-0.1*i*dxx, zw1-0.1*i*dzx, xw2-0.1*i*dxx, zw2-0.1*i*dzx, 1 ) ~=
						AutoSteeringEngine.hasFruitsSimple( vehicle, xw1-0.1*i*dxx, zw1-0.1*i*dzx, xw2-0.1*i*dxx, zw2-0.1*i*dzx, -1 ) then
					vehicle.aseDirectionBeforeTurn.xOffset = -0.1*i
					vehicle.aseDirectionBeforeTurn.x = vehicle.aseDirectionBeforeTurn.x-0.1*i*dxx
					vehicle.aseDirectionBeforeTurn.z = vehicle.aseDirectionBeforeTurn.z-0.1*i*dzx
					break;
				end
			end
		end
		
		xw1 = vehicle.aseDirectionBeforeTurn.x + 2 * dxx
		zw1 = vehicle.aseDirectionBeforeTurn.z + 2 * dxz
		xw2 = vehicle.aseDirectionBeforeTurn.x - 2 * dxx
		zw2 = vehicle.aseDirectionBeforeTurn.z - 2 * dxz
		
		local z0 = -3
		for i=0,30 do
			local z = -0.1*i
			if AutoSteeringEngine.hasFruitsSimple( vehicle, xw1+z*dxz, zw1+z*dzz, xw2+z*dxz, zw2+z*dzz, 1 ) then
				z0 = z
				break;
			end
		end
		for i=0,30 do
			local z = z0 + 0.1*i
			if not AutoSteeringEngine.hasFruitsSimple( vehicle, xw1+z*dxz, zw1+z*dzz, xw2+z*dxz, zw2+z*dzz, 1 ) then
				vehicle.aseDirectionBeforeTurn.zOffset = z
				vehicle.aseDirectionBeforeTurn.x = vehicle.aseDirectionBeforeTurn.x+z*dxz
				vehicle.aseDirectionBeforeTurn.z = vehicle.aseDirectionBeforeTurn.z+z*dzz
				break;
			end
		end
	end
	
	--local a0 = vehicle.aseDirectionBeforeTurn.a
	--local a1 = -AutoSteeringEngine.getTurnAngle( vehicle )
	--local f  = math.pi / 90
	--for i=1,90 do
	--	setRotation( vehicle.aseChain.headlandNode, 0, a1 + i*f, 0 );
	--	local dxz, _,dzz  = localDirectionToWorld( vehicle.aseChain.headlandNode, 0, 0, 1 )
	--	local dxx, _,dzx  = localDirectionToWorld( vehicle.aseChain.headlandNode, 1, 0, 0 )			
	--	local xw1,zw1,xw2,zw2 
	--	xw1 = vehicle.aseDirectionBeforeTurn.x + 2 * dxx
	--	zw1 = vehicle.aseDirectionBeforeTurn.z + 2 * dxz
	--	xw2 = vehicle.aseDirectionBeforeTurn.x - 2 * dxx
	--	zw2 = vehicle.aseDirectionBeforeTurn.z - 2 * dxz
  --
	--	if AutoSteeringEngine.hasFruitsSimple( vehicle, xw1, zw1, xw2, zw2, 1 ) then
	--		vehicle.aseDirectionBeforeTurn.a = a0 + (i-1) * f
	--		setRotation( vehicle.aseChain.headlandNode, 0, -AutoSteeringEngine.getTurnAngle( vehicle ), 0 );
	--		break
	--	end
  --
	--	setRotation( vehicle.aseChain.headlandNode, 0, a1 - i*f, 0 );
	--	dxz, _,dzz  = localDirectionToWorld( vehicle.aseChain.headlandNode, 0, 0, 1 )
	--	dxx, _,dzx  = localDirectionToWorld( vehicle.aseChain.headlandNode, 1, 0, 0 )			
	--	xw1 = vehicle.aseDirectionBeforeTurn.x + 2 * dxx
	--	zw1 = vehicle.aseDirectionBeforeTurn.z + 2 * dxz
	--	xw2 = vehicle.aseDirectionBeforeTurn.x - 2 * dxx
	--	zw2 = vehicle.aseDirectionBeforeTurn.z - 2 * dxz
  --
	--	if AutoSteeringEngine.hasFruitsSimple( vehicle, xw1, zw1, xw2, zw2, 1 ) then
	--		vehicle.aseDirectionBeforeTurn.a = a0 - (i-1) * f
	--		setRotation( vehicle.aseChain.headlandNode, 0, -AutoSteeringEngine.getTurnAngle( vehicle ), 0 );
	--		break
	--	end
	--end
	
	--print("a: "..tostring( math.deg( a0 ) ).." -> "..tostring( math.deg( vehicle.aseDirectionBeforeTurn.a ) ) )
	--print("x: "..tostring( vehicle.aseDirectionBeforeTurn.xOffset ).." z: "..tostring( vehicle.aseDirectionBeforeTurn.zOffset ).." ax: "..tostring( vehicle.aseActiveX ) )
end	

------------------------------------------------------------------------
-- getTurnDistance
------------------------------------------------------------------------
function AutoSteeringEngine.getTurnDistance( vehicle )
	if     vehicle.aseChain.refNode             == nil
			or vehicle.aseDirectionBeforeTurn       == nil
			or vehicle.aseDirectionBeforeTurn.trace == nil 
			or vehicle.aseDirectionBeforeTurn.traceIndex < 1 then
		return 0
	end;
	local _,y,_ = getWorldTranslation( vehicle.aseChain.refNode );
	local x,_,z = worldToLocal( vehicle.aseChain.refNode, vehicle.aseDirectionBeforeTurn.trace[vehicle.aseDirectionBeforeTurn.traceIndex].px, y, vehicle.aseDirectionBeforeTurn.trace[vehicle.aseDirectionBeforeTurn.traceIndex].pz )
	return math.sqrt( x*x + z*z )
end

------------------------------------------------------------------------
-- getTraceLength
------------------------------------------------------------------------
function AutoSteeringEngine.getTraceLength( vehicle )
	if     vehicle.aseChain.refNode         == nil
			or vehicle.aseDirectionBeforeTurn   == nil then
		return 0;
	end
	if     vehicle.aseDirectionBeforeTurn.sx    == nil
			or vehicle.aseDirectionBeforeTurn.sz    == nil
			or vehicle.aseDirectionBeforeTurn.trace == nil then
		return 0;
	end;
	
	if table.getn(vehicle.aseDirectionBeforeTurn.trace) < 2 then
		return 0;
	end;
		
	local i = AutoSteeringEngine.getFirstTraceIndex( vehicle );
	if i == nil then
		return 0;
	end
	
	local x = vehicle.aseDirectionBeforeTurn.trace[vehicle.aseDirectionBeforeTurn.traceIndex].px - vehicle.aseDirectionBeforeTurn.sx;
	local z = vehicle.aseDirectionBeforeTurn.trace[vehicle.aseDirectionBeforeTurn.traceIndex].pz - vehicle.aseDirectionBeforeTurn.sz;
	
	return math.sqrt( x*x + z*z );
end;

------------------------------------------------------------------------
-- getTurnAngle
------------------------------------------------------------------------
function AutoSteeringEngine.getTurnAngle( vehicle )
	if     vehicle.aseChain.refNode         == nil
			or vehicle.aseDirectionBeforeTurn   == nil then
		return 0;
	end
	if vehicle.aseDirectionBeforeTurn.a == nil then
		local i = AutoSteeringEngine.getFirstTraceIndex( vehicle );
		if i == nil then
			return 0
		end
		if i == vehicle.aseDirectionBeforeTurn.traceIndex then
			return 0
		end
		local l = AutoSteeringEngine.getTraceLength( vehicle );
		if l < 2 then
			return 0
		end

		local vx = vehicle.aseDirectionBeforeTurn.trace[vehicle.aseDirectionBeforeTurn.traceIndex].px - vehicle.aseDirectionBeforeTurn.trace[i].px;
		local vz = vehicle.aseDirectionBeforeTurn.trace[vehicle.aseDirectionBeforeTurn.traceIndex].pz - vehicle.aseDirectionBeforeTurn.trace[i].pz;		
		vehicle.aseDirectionBeforeTurn.a = Utils.getYRotationFromDirection(vx,vz);
		
		if vehicle.aseDirectionBeforeTurn.a == nil then
			print("NIL!!!!");
		end
	end;

	local x,y,z = localDirectionToWorld( vehicle.aseChain.refNode, 0,0,1 );
	
	local angle = AutoSteeringEngine.normalizeAngle( Utils.getYRotationFromDirection(x,z) - vehicle.aseDirectionBeforeTurn.a );	
	return angle;
end;	

------------------------------------------------------------------------
-- getRelativeTranslation
------------------------------------------------------------------------
function AutoSteeringEngine.getRelativeTranslation(root,node)
	local x,y,z;
	if getParent(node)==root then
		x,y,z = getTranslation(node);
	else
		x,y,z = worldToLocal(root,getWorldTranslation(node));
	end;
	return x,y,z;
end

------------------------------------------------------------------------
-- getRelativeYRotation
------------------------------------------------------------------------
function AutoSteeringEngine.getRelativeYRotation(root,node)
	local x, y, z = worldDirectionToLocal(node, localDirectionToWorld(root, 0, 0, 1))
	local dot = z
	dot = dot / Utils.vector2Length(x, z)
	local angle = math.acos(dot)
	if x < 0 then
		angle = -angle
	end
	return angle
end

------------------------------------------------------------------------
-- getRelativeYRotation
------------------------------------------------------------------------
function AutoSteeringEngine.getRelativeZRotation(root,node)
	local x, y, z = worldDirectionToLocal(node, localDirectionToWorld(root, 0, 1, 0))
	local dot = y
	dot = dot / Utils.vector2Length(x, y)
	local angle = math.acos(dot)
	if x < 0 then
		angle = -angle
	end
	return angle
end

------------------------------------------------------------------------
-- initChain
------------------------------------------------------------------------
function AutoSteeringEngine.initChain( vehicle, iRefNode, zOffset, wheelBase, maxSteering, widthOffset, turnOffset )
	
	vehicle.aseChain = {};
	vehicle.aseChain.resetCounter = AutoSteeringEngine.resetCounter
		
	vehicle.aseChain.length       = ASEGlobals.chainMax * ASEGlobals.chainLen;
	if ASEGlobals.chainMax >= 2 and math.abs( ASEGlobals.chainLenInc ) > 1E-3 then
		vehicle.aseChain.length     = vehicle.aseChain.length + 0.5 * ( ASEGlobals.chainMax - 1 ) * ( ASEGlobals.chainMax - 2 ) * ASEGlobals.chainLenInc;
	end
	vehicle.aseChain.zOffset      = zOffset;
	vehicle.aseChain.wheelBase    = wheelBase;
	vehicle.aseChain.invWheelBase = 1 / wheelBase;
	vehicle.aseChain.maxSteering  = maxSteering;

	if not vehicle.isServer then 
		vehicle.aseChain.refNode = iRefNode
		return 
	end

	vehicle.aseChain.refNode      = createTransformGroup( "acChainRef" );
	link( iRefNode, vehicle.aseChain.refNode );
	setTranslation( vehicle.aseChain.refNode, 0,0, vehicle.aseChain.zOffset );
	vehicle.aseChain.headlandNode = createTransformGroup( "acHeadland" );
	link( vehicle.aseChain.refNode, vehicle.aseChain.headlandNode );
	
	local node    = {};
	node.index    = createTransformGroup( "acChain0" );
	node.index2   = createTransformGroup( "acChain0_rot" );
	node.status   = 0;
	node.angle    = 0;
	node.steering = 0;
	node.rotation = 0;
	node.isField  = false;
	node.distance = 0;
	node.tool     = {};
	link( vehicle.aseChain.refNode, node.index );
	link( node.index, node.index2 );

	local distance = 0;
	local nodes = {};
	nodes[1] = node;
	
	for i=1,ASEGlobals.chainMax do
		local parent   = nodes[i];
		local text     = string.format("acChain%i",i)
		local node2    = {};
		local add      = ASEGlobals.chainLen + ( i-1 ) * ASEGlobals.chainLenInc;
		distance       = distance + add;
		node2.index    = createTransformGroup( text );
		node2.index2   = createTransformGroup( text.."_rot" );
		node2.status   = 0;
		node2.angle    = 0;
		node2.steering = 0;
		node2.rotation = 0;
		node2.isField  = false;
		node2.distance = distance;
		node2.tool     = {};
		
		link( parent.index2, node2.index );
		link( node2.index, node2.index2 );
		setTranslation( node2.index, 0,0,add );
		
		nodes[#nodes+1] = node2;
	end
	
	vehicle.aseChain.nodes = nodes;

	vehicle.aseChain.tNode = {};
	
	vehicle.aseChain.tNode[0] = createTransformGroup( "acTJoin" );
	vehicle.aseChain.tNode[1] = createTransformGroup( "acTJoin1" );
	vehicle.aseChain.tNode[2] = createTransformGroup( "acTJoin1" );
	link(vehicle.aseChain.refNode, vehicle.aseChain.tNode[0]);
	link(vehicle.aseChain.tNode[0],vehicle.aseChain.tNode[1]);
	link(vehicle.aseChain.tNode[1],vehicle.aseChain.tNode[2]);
	
end

function AutoSteeringEngine.deleteNode( index, noUnlink )
	return pcall(AutoSteeringEngine.deleteNode1, index, withUnlink );
end

function AutoSteeringEngine.deleteNode1( index, noUnlink )

	if noUnlink then
	else
		unlink( index )
	end
	delete( index )
end

------------------------------------------------------------------------
-- initChain
------------------------------------------------------------------------
function AutoSteeringEngine.deleteChain( vehicle )

	AutoSteeringEngine.deleteTools( vehicle )

	if vehicle.aseChain == nil then return end

	local i
	if vehicle.aseChain.nodes ~= nil then
		local n = vehicle.aseChain.nodes
		vehicle.aseChain.nodes = nil
		for j=-1,ASEGlobals.chainMax-1 do
			i = ASEGlobals.chainMax - j
			AutoSteeringEngine.deleteNode( n[i].index2 );
			AutoSteeringEngine.deleteNode( n[i].index  );
		end
	end
	
	if vehicle.aseChain.tNode ~= nil then
		AutoSteeringEngine.deleteNode( vehicle.aseChain.tNode[2] );
		AutoSteeringEngine.deleteNode( vehicle.aseChain.tNode[1] );
		AutoSteeringEngine.deleteNode( vehicle.aseChain.tNode[0], true );
		vehicle.aseChain.tNode = nil 
	end

	if vehicle.aseChain.headlandNode ~= nil then
		AutoSteeringEngine.deleteNode( vehicle.aseChain.headlandNode );
		vehicle.aseChain.headlandNode = nil
	end
	
	if vehicle.aseChain.refNode == nil then
		AutoSteeringEngine.deleteNode( vehicle.aseChain.refNode );
		vehicle.aseChain.refNode = nil
	end
	
	vehicle.aseChain = nil
	vehicle.aseCurrentField = nil		
	
end

------------------------------------------------------------------------
-- getSpecialToolSettings
------------------------------------------------------------------------
function AutoSteeringEngine.getSpecialToolSettings( vehicle )
	local settings = {}
	
	settings.noReverse = false
	settings.leftOnly  = false
	settings.rightOnly = false
	
	if not AutoSteeringEngine.hasTools( vehicle ) then
		return settings;
	end
	
	for _,tool in pairs(vehicle.aseTools) do
		if tool.isPlough then
			if tool.aiForceTurnNoBackward then
				settings.noReverse = true
			end
			--if     tool.obj.rotationPart               == nil
			--		or tool.obj.rotationPart.turnAnimation == nil then
			--	settings.rightOnly = true
			--end
		elseif tool.isCombine then
		--	if tool.xl+tool.xl+tool.xl < -tool.xr then
		--		settings.rightOnly = true
		--	end
		--	if tool.xl > -tool.xr-tool.xr-tool.xr then
		--		settings.leftOnly  = true
		--	end
		end
	end

	return settings
end

------------------------------------------------------------------------
-- addTool
------------------------------------------------------------------------
function AutoSteeringEngine.addTool( vehicle, object, reference )

	local tool       = {};
	local marker     = {};
	local extraNodes = {};

	if AtResetCounter == nil or AtResetCounter < 1 then
		--if object.name ~= nil then print("Adding... "..object.name) else print("Adding something") end
	end
	
	tool.steeringAxleNode   = object.steeringAxleNode;
	if tool.steeringAxleNode == nil then
		tool.steeringAxleNode = object.components[1].node
	end
	
	tool.checkZRotation  = false
	
	if 			getName( object.components[1].node ) == "poettingerServo650" 
			and table.getn(object.components)        >= 2 then
		tool.steeringAxleNode = object.components[2].node
		tool.checkZRotation   = true
	end
	
	if tool.checkZRotation then
		local c = getChild( tool.steeringAxleNode, "ASESteeringAxle" )
		if c ~= nil and c > 0 then
			tool.steeringAxleNode = c
		else
			local parent = tool.steeringAxleNode
			tool.steeringAxleNode = createTransformGroup( "ASESteeringAxle" )
			extraNodes[#extraNodes+1] = tool.steeringAxleNode
			link( parent, tool.steeringAxleNode )
		end
	end
	
	local xo,yo,zo = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode, reference );
	
	tool.obj                           = object;
	tool.xOffset                       = xo;
	tool.zOffset                       = zo;
	tool.isCombine                     = false;
	tool.isPlough                      = false;
	tool.isSprayer                     = false;
	tool.isMower                       = false;
	tool.isSowingMachine               = false;
	tool.isAITool                      = false;
	tool.specialType                   = "";
	tool.aiTerrainDetailChannel1       = Utils.getNoNil( object.aiTerrainDetailChannel1      ,-1 );
	tool.aiTerrainDetailChannel2       = Utils.getNoNil( object.aiTerrainDetailChannel2      ,-1 );
	tool.aiTerrainDetailChannel3       = Utils.getNoNil( object.aiTerrainDetailChannel3      ,-1 );
	tool.aiTerrainDetailProhibitedMask = Utils.getNoNil( object.aiTerrainDetailProhibitedMask,0 );
	tool.aiRequiredFruitType           = Utils.getNoNil( object.aiRequiredFruitType          ,FruitUtil.FRUITTYPE_UNKNOWN );
	tool.aiRequiredMinGrowthState      = Utils.getNoNil( object.aiRequiredMinGrowthState     ,0 );
	tool.aiRequiredMaxGrowthState      = Utils.getNoNil( object.aiRequiredMaxGrowthState     ,0 );
	tool.aiProhibitedFruitType         = Utils.getNoNil( object.aiProhibitedFruitType        ,FruitUtil.FRUITTYPE_UNKNOWN );
	tool.aiProhibitedMinGrowthState    = Utils.getNoNil( object.aiProhibitedMinGrowthState   ,0 );
	tool.aiProhibitedMaxGrowthState    = Utils.getNoNil( object.aiProhibitedMaxGrowthState   ,0 );
	tool.aiForceTurnNoBackward         = Utils.getNoNil( object.aiForceTurnNoBackward        ,false );
	tool.b2                            = nil;
	tool.invert                        = false;
	tool.outTerrainDetailChannel       = -1;	
	
	if tool.checkZRotation then
		tool.aiForceTurnNoBackward = true
	end

	local useAI = true
	
	if      SpecializationUtil.hasSpecialization(Combine, object.specializations) then
		useAI = false
	elseif  object.customEnvironment ~= nil
			and SpecializationUtil.hasSpecialization(SpecializationUtil.getSpecialization( object.customEnvironment ..".HorschSW3500S" ), object.specializations) then 
		useAI = false
  end
	
	if useAI and object.aiLeftMarker ~= nil and object.aiRightMarker ~= nil then
-- tool with AI support		
		tool.isAITool = true
		if AtResetCounter == nil or AtResetCounter < 1 then
			--print("object has AI support");
		end
		
		if object.aiLeftMarker ~= nil then
			marker[#marker+1] = object.aiLeftMarker
		end
		
		if object.aiRightMarker ~= nil then
			marker[#marker+1] = object.aiRightMarker
		end
		
		tool.aiBackMarker = object.aiBackMarker;		

		if     object.packomatBase ~= nil then
			tool.isPlough = false
			tool.specialType = "Packomat"
			tool.outTerrainDetailChannel = g_currentMission.ploughChannel
		elseif  object.customEnvironment   ~= nil
				and SpecializationUtil.hasSpecialization(SpecializationUtil.getSpecialization( object.customEnvironment ..".Lemken_Gigant" ), object.specializations) then
			tool.outTerrainDetailChannel = g_currentMission.cultivatorChannel
			tool.aiForceTurnNoBackward   = true
		elseif SpecializationUtil.hasSpecialization(Plough, object.specializations) then
			tool.isPlough = true
			tool.outTerrainDetailChannel = g_currentMission.ploughChannel
			if getName( object.components[1].node ) == "poettingerServo650" then
				tool.specialType = "poettingerServo650"
			end
		elseif SpecializationUtil.hasSpecialization(Cultivator, object.specializations) then
			tool.outTerrainDetailChannel = g_currentMission.cultivatorChannel
		elseif SpecializationUtil.hasSpecialization(SowingMachine, object.specializations) then
			tool.outTerrainDetailChannel = g_currentMission.sowingChannel
			tool.isSowingMachine = true
		end
	else
		local areas = nil;

		if      object.attacherJoint              ~= nil
				and object.attacherJoint.jointType    ~= nil
				and ( object.attacherJoint.jointType  == Vehicle.JOINTTYPE_TRAILERLOW
				   or object.attacherJoint.jointType  == Vehicle.JOINTTYPE_TRAILER ) then
			tool.aiForceTurnNoBackward = true;
		elseif object.aiForceTurnNoBackward == nil then
			tool.aiForceTurnNoBackward = false;
		end
	
		if     SpecializationUtil.hasSpecialization(Sprayer, object.specializations) then
		-- sprayer	
			if AtResetCounter == nil or AtResetCounter < 1 then
				--print("object is sprayer");
			end
			
			tool.isSprayer                     = true
			tool.aiTerrainDetailChannel1       = g_currentMission.cultivatorChannel;
			tool.aiTerrainDetailChannel2       = g_currentMission.ploughChannel;
			tool.aiTerrainDetailChannel3       = g_currentMission.sowingChannel;
			tool.aiTerrainDetailProhibitedMask = 2 ^ g_currentMission.sprayChannel;
			tool.outTerrainDetailChannel       = g_currentMission.sprayChannel;
		elseif SpecializationUtil.hasSpecialization(Combine, object.specializations) then
		-- Combine
			if AtResetCounter == nil or AtResetCounter < 1 then
				--print("object is combine");
			end
			
			tool.isCombine = true;
			
			if object.aiLeftMarker ~= nil and object.aiRightMarker ~= nil then
				local tempArea = {};
				tempArea.start  = object.aiLeftMarker;
				tempArea.width  = object.aiRightMarker;
				tempArea.height = object.aiBackMarker;		
				areas    = {};
				areas[1] = tempArea;
			end
			
		elseif SpecializationUtil.hasSpecialization(Mower, object.specializations) then
		-- Mower
			if AtResetCounter == nil or AtResetCounter < 1 then
				--print("object is mower");
			end
			
			tool.isMower = true;			
			areas = object.mowerCutAreas;

--	elseif SpecializationUtil.hasSpecialization(Tedder, object.specializations) then
--	-- Tedder
--		if AtResetCounter == nil or AtResetCounter < 1 then
--			print("object is tedder");
--		end
--		
--		tool.isTedder = true;			
--		
--	elseif SpecializationUtil.hasSpecialization(Windrower, object.specializations) then
--	-- Windrower
--		if AtResetCounter == nil or AtResetCounter < 1 then
--			print("object is windrower");
--		end
--		
--		tool.isWindrower = true;			
			
		elseif SpecializationUtil.hasSpecialization(FruitPreparer, object.specializations) then
		-- FruitPreparer
			if AtResetCounter == nil or AtResetCounter < 1 then
				--print("object is fruit preparer");
			end
			
			local fruitDesc = FruitUtil.fruitIndexToDesc[object.fruitPreparerFruitType];
			if fruitDesc == nil then return 0 end
			
			areas = object.fruitPreparerAreas;
			
			tool.aiRequiredFruitType        = object.fruitPreparerFruitType;
      tool.aiRequiredMinGrowthState   = fruitDesc.minPreparingGrowthState;
      tool.aiRequiredMaxGrowthState   = fruitDesc.maxPreparingGrowthState; 
		elseif SpecializationUtil.hasSpecialization(Plough, object.specializations) then
		-- Plough
			if AtResetCounter == nil or AtResetCounter < 1 then
				--print("object is plough");
			end
			
			tool.isPlough = true			
			tool.outTerrainDetailChannel = g_currentMission.ploughChannel

		elseif SpecializationUtil.hasSpecialization(Cultivator, object.specializations) then
		-- Cultivator
			if AtResetCounter == nil or AtResetCounter < 1 then
				--print("object is cultivator");
			end
			
			tool.outTerrainDetailChannel = g_currentMission.cultivatorChannel

    --------------------------------------------------------
		-- Poettinger X8
		elseif  object.customEnvironment ~= nil
				and SpecializationUtil.hasSpecialization(SpecializationUtil.getSpecialization( object.customEnvironment ..".poettingerX8" ), object.specializations) 
				and object.mowerCutAreasSend ~= nil 
				then

			tool.specialType = "Poettinger X8"
			tool.isMower     = true
			areas = object.mowerCutAreasSend
    --------------------------------------------------------
		-- Poettinger AlphaMotion
		elseif  object.customEnvironment   ~= nil
				and SpecializationUtil.hasSpecialization(SpecializationUtil.getSpecialization( object.customEnvironment ..".poettingerAlpha" ), object.specializations) 
				and object.alpMot              ~= nil
				and object.alpMot.cuttingAreas ~= nil
				then

			tool.specialType = "Poettinger AlphaMotion"
			tool.isMower     = true
			areas = object.alpMot.cuttingAreas
    --------------------------------------------------------
		-- Taarup Mower Cut
		elseif  object.customEnvironment ~= nil
				and ( SpecializationUtil.hasSpecialization(SpecializationUtil.getSpecialization( object.customEnvironment ..".TaarupMowerCut" ), object.specializations) 
				   or SpecializationUtil.hasSpecialization(SpecializationUtil.getSpecialization( object.customEnvironment ..".KevCond240" ), object.specializations)  
				   or SpecializationUtil.hasSpecialization(SpecializationUtil.getSpecialization( object.customEnvironment ..".KevMT" ), object.specializations)  
				   or SpecializationUtil.hasSpecialization(SpecializationUtil.getSpecialization( object.customEnvironment ..".Taarup3532" ), object.specializations) ) 
				and object.mowerCutAreas     ~= nil
				then

			tool.specialType = "Taarup Mower"
			tool.isMower     = true
			areas = object.mowerCutAreas
    --------------------------------------------------------
		elseif  object.customEnvironment ~= nil
				and ( SpecializationUtil.hasSpecialization(SpecializationUtil.getSpecialization( object.customEnvironment ..".HorschSW3500S" ), object.specializations) ) 
				then

			tool.specialType = "Horsch SW3500 S"
			areas = {} --object.cuttingAreas
			local tempArea = {};
			tempArea.start  = object.aiLeftMarker;
			tempArea.width  = object.aiRightMarker;
		--tempArea.height = object.aiBackMarker;		
			tempArea.height = createTransformGroup( "acBackNew" )
			extraNodes[#extraNodes+1] = tempArea.height
			link( tempArea.start, tempArea.height )
			setTranslation( tempArea.height, 0, 0, -4 )
			areas[1] = tempArea;
			
			tool.aiForceTurnNoBackward   = true
			tool.isSowingMachine         = true
			tool.outTerrainDetailChannel = g_currentMission.sowingChannel
    --------------------------------------------------------
		else
			return 0
		end
		
		if areas == nil then areas = object.cuttingAreas; end
		if areas == nil then return 0 end		

		local zBack 
		
		--print(tostring(table.getn(areas)))
		
		for _, area in pairs(areas) do
			local xx, zz, x1, z1 = 0,0,0,0
			local backIndex      = area.height
			if not tool.isCombine then
				xx,_,z1 = AutoSteeringEngine.getRelativeTranslation( area.start, area.height )
				x1,_,zz = AutoSteeringEngine.getRelativeTranslation( area.start, area.width )
			end
			
			if     math.abs( xx ) < 1E-2 and zz < 1E-2 then
				marker[#marker+1] = area.start;
				marker[#marker+1] = area.width;
			elseif math.abs( x1 ) < 1E-2 and z1 < 1E-2 then
				marker[#marker+1] = area.start;
				marker[#marker+1] = area.height;
				backIndex         = area.width;
			else
				marker[#marker+1] = area.start
				marker[#marker+1] = area.width
				marker[#marker+1] = area.height
				marker[#marker+1] = createTransformGroup( "additionalMarker" )
			  extraNodes[#extraNodes+1] = marker[#marker]
				link( area.start, marker[#marker] )
				setTranslation( marker[#marker], xx+x1, 0, zz+z1 )
				if zz < 0 and z1 < 0 then
					backIndex = marker[#marker]
				elseif zz < z1 then
					backIndex = area.width
				end
			end
			
			local _,_,zzBack = AutoSteeringEngine.getRelativeTranslation( tool.steeringAxleNode, backIndex )
			if zBack == nil or zzBack > zBack then
				zBack = zzBack
				tool.aiBackMarker = backIndex;
			end
		end					

		--print(tostring(table.getn(marker)))
	end

	if #marker < 1 then 
		--if AtResetCounter == nil or AtResetCounter < 1 then
		--	print("no marker found") 
		--end
		return 0
	end

	if object.aiBackMarker == nil then
		tool.aiBackMarker = marker[1];
	end
	
	tool.refNode = reference;		
	tool.marker  = marker;
	
	if table.getn( extraNodes ) > 0 then
		tool.extraNodes = extraNodes;
	end
	
		--if object.lengthOffset ~= nil and object.lengthOffset < 0 then			
	if math.abs( AutoSteeringEngine.getRelativeYRotation( vehicle.aseChain.refNode, tool.steeringAxleNode ) ) > 0.6 * math.pi then
	-- wrong rotation ???
		--print("wrong rotation");
		tool.invert = not tool.invert;
	end	
	--local _,_,rsz = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, tool.steeringAxleNode )
	--if rsz > 1 then
	--	tool.invert = not tool.invert;
	--end		
	
	local xl, xr, zz, zb;
	
	for i=1,#marker do
		local x,_,z = AutoSteeringEngine.getRelativeTranslation(tool.steeringAxleNode,marker[i]);
		if tool.invert then x = -x end
		if xl == nil or xl < x then xl = x end
		if xr == nil or xr > x then xr = x end
		if zz == nil or zz < z then zz = z end
		if zb == nil or zb > z then zb = z end
	end
	
	tool.xl = xl - tool.xOffset;
	tool.xr = xr - tool.xOffset;
	tool.z  = zz - tool.zOffset;
	tool.zb = zb - tool.zOffset;
	
	tool.b2 = 0
	if tool.aiForceTurnNoBackward then
		tool.b1 = AutoSteeringEngine.findComponentJointDistance( vehicle, tool, object )
	
		if object.wheels ~= nil then
			local wna,wza=0,0;
			for i,wheel in pairs(object.wheels) do
				local f = AutoSteeringEngine.getToolWheelFactor( vehicle, tool, object, i )
				if f > 1E-3 then
					local _,_,wz = AutoSteeringEngine.getRelativeTranslation(tool.steeringAxleNode,wheel.driveNode);
					wza = wza + f * wz;
					wna = wna + f;		
				end
			end
			if wna > 0 then
				tool.b2 = wza / wna - tool.zOffset;
				if tool.invert then tool.b2 = -tool.b2 end
			--print(string.format("wna=%i wza=%f b2=%f ofs=%f",wna,wza,tool.b2,tool.zOffset))
			end
		end
	else
		tool.b1 = tool.z;
	end
	
	local i = 0
	
	if vehicle.aseTools == nil then
		vehicle.aseTools ={};
		i = 1
	else
		i = table.getn(vehicle.aseTools) + 1
	end

	vehicle.aseTools[i] = tool
	return i	
end

------------------------------------------------------------------------
-- isToolWheelRelevant
------------------------------------------------------------------------
function AutoSteeringEngine.getToolWheelFactor( vehicle, tool, object, i )
	return Utils.getNoNil( object.wheels[i].lateralStiffness, 1 )
end

------------------------------------------------------------------------
-- deleteTools
------------------------------------------------------------------------
function AutoSteeringEngine.deleteTools( vehicle )

	if vehicle ~= nil and vehicle.aseTools ~= nil and table.getn( vehicle.aseTools ) > 0 then
		for _,tool in pairs( vehicle.aseTools ) do
			if tool.extraNodes ~= nil and table.getn( tool.extraNodes ) > 0 then
				for _,n in pairs( tool.extraNodes ) do
					AutoSteeringEngine.deleteNode( n )
				end
			end
		end
	end
	
	vehicle.aseTools = nil
end

------------------------------------------------------------------------
-- checkAllowedToDrive
------------------------------------------------------------------------
function AutoSteeringEngine.checkAllowedToDrive( vehicle )

	if vehicle.aseCurrentFieldCo ~= nil then
		local x,_,z = getWorldTranslation( vehicle.aseChain.refNode )
		AutoSteeringEngine.checkField( vehicle, x, z )
		if vehicle.aseCurrentFieldCo ~= nil then
			return false
		end
	end
	
	if vehicle.acIsCPStopped then
		vehicle.acIsCPStopped = false;
		return false
	end
	
	if vehicle.aseTools == nil or table.getn(vehicle.aseTools) < 1 then
		return false
	end
	
  local allowedToDrive = true
	
	for i,tool in pairs(vehicle.aseTools) do
		local self = tool.obj
		
		if  tool.isCombine then -- and tool.obj.isThreshing then
			
			if not Combine.getIsThreshingAllowed( self ) then
				allowedToDrive = false
			end
			
			if (0 < self.grainTankFillLevel or 0 > self.grainTankCapacity) and (self.grainTankFillLevel >= self.grainTankCapacity * 0.8 or next(self.combineTrailersInRange) ~= nil) then
				do
					local pipeState = Combine.getCombineTrailerInRangePipeState(self)
					if pipeState > 0 then
						Combine.setPipeState(self,pipeState)
					else
						Combine.setPipeState(self,2)
					end
					if next(self.combineTrailersInRange) ~= nil then
						self.waitForDischargeTime = self.time + vehicle.acDeltaTimeoutStart
					end
					if self.grainTankFillLevel >= self.grainTankCapacity and 0 < self.grainTankCapacity then
						self.waitingForDischarge = true
						self.waitForDischargeTime = self.time + vehicle.acDeltaTimeoutStart
					end
				end
			elseif self.waitingForDischarge and 0 >= self.grainTankFillLevel or self.waitForDischargeTime <= self.time then
				self.waitingForDischarge = false
				if next(self.combineTrailersInRange) == nil then
					Combine.setPipeState(self,1)
				end
			end
				
			if self.grainTankCapacity == 0 then
				if not self.pipeStateIsUnloading[self.currentPipeState] then
					allowedToDrive = false
				end
				if not self.isPipeUnloading and (0 < self.lastArea or 0 < self.lastLostGrainTankFillLevel) then
					self.waitingForTrailerToUnload = true
				end
			elseif self.grainTankFillLevel >= self.grainTankCapacity then
				allowedToDrive = false
			end
			if self.waitingForTrailerToUnload then
				if self.lastValidGrainTankFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
					do
						local trailer = self:findTrailerToUnload(self.lastValidGrainTankFruitType)
						if trailer ~= nil then
							self.waitingForTrailerToUnload = false
						end
					end
				else
					self.waitingForTrailerToUnload = false
				end
			end
			if ( self.grainTankFillLevel >= self.grainTankCapacity and self.grainTankCapacity > 0 ) or self.waitingForTrailerToUnload or self.waitingForDischarge then
				allowedToDrive = false;
			end

			if not self:getIsThreshingAllowed(true) then
				allowedToDrive = false
				self.waitingForWeather = true
			elseif self.waitingForWeather then
				self.waitingForWeather = false
			end
			
		elseif  self.capacity  ~= nil
				and self.capacity  > 0 
				and self.fillLevel ~= nil
				and self.fillLevel <= 0 then
			allowedToDrive = false
    end
		
		if     tool.specialType == "Horsch SW3500 S" then
			vehicle.aseTools[i].aiProhibitedFruitType      = self.currentFillType
			if vehicle.aseTools[i].aiProhibitedFruitType ~= FruitUtil.FRUITTYPE_UNKNOWN then
				vehicle.aseTools[i].aiProhibitedMinGrowthState = 0
				vehicle.aseTools[i].aiProhibitedMaxGrowthState = FruitUtil.fruitIndexToDesc[vehicle.aseTools[i].aiProhibitedFruitType].maxHarvestingGrowthState			
			end
		elseif tool.isSowingMachine then
			if self.useDirectPlanting then
				vehicle.aseTools[i].aiProhibitedFruitType      = self.seeds[self.currentSeed]
				vehicle.aseTools[i].aiProhibitedMinGrowthState = 0
				vehicle.aseTools[i].aiProhibitedMaxGrowthState = FruitUtil.fruitIndexToDesc[vehicle.aseTools[i].aiProhibitedFruitType].maxHarvestingGrowthState
			else
				vehicle.aseTools[i].aiProhibitedFruitType = FruitUtil.FRUITTYPE_UNKNOWN
			end
		elseif tool.isAITool then
			vehicle.aseTools[i].aiTerrainDetailChannel1       = Utils.getNoNil( tool.obj.aiTerrainDetailChannel1      ,-1 );
			vehicle.aseTools[i].aiTerrainDetailChannel2       = Utils.getNoNil( tool.obj.aiTerrainDetailChannel2      ,-1 );
			vehicle.aseTools[i].aiTerrainDetailChannel3       = Utils.getNoNil( tool.obj.aiTerrainDetailChannel3      ,-1 );
			vehicle.aseTools[i].aiTerrainDetailProhibitedMask = Utils.getNoNil( tool.obj.aiTerrainDetailProhibitedMask,0 );
			vehicle.aseTools[i].aiRequiredFruitType           = Utils.getNoNil( tool.obj.aiRequiredFruitType          ,FruitUtil.FRUITTYPE_UNKNOWN );
			vehicle.aseTools[i].aiRequiredMinGrowthState      = Utils.getNoNil( tool.obj.aiRequiredMinGrowthState     ,0 );
			vehicle.aseTools[i].aiRequiredMaxGrowthState      = Utils.getNoNil( tool.obj.aiRequiredMaxGrowthState     ,0 );
			vehicle.aseTools[i].aiProhibitedFruitType         = Utils.getNoNil( tool.obj.aiProhibitedFruitType        ,FruitUtil.FRUITTYPE_UNKNOWN );
			vehicle.aseTools[i].aiProhibitedMinGrowthState    = Utils.getNoNil( tool.obj.aiProhibitedMinGrowthState   ,0 );
			vehicle.aseTools[i].aiProhibitedMaxGrowthState    = Utils.getNoNil( tool.obj.aiProhibitedMaxGrowthState   ,0 );
			if tool.obj.aiForceTurnNoBackward then
				vehicle.aseTools[i].aiForceTurnNoBackward       = true
			end
		end
	end
	
	
	
	if not allowedToDrive then
		vehicle.lastNotAllowedToDrive = true
	elseif vehicle.lastNotAllowedToDrive then
		vehicle.lastNotAllowedToDrive = false
		for i,tool in pairs(vehicle.aseTools) do
			vehicle.aseTools[i].lowerStateOnFruits = true			
		end
		AutoSteeringEngine.ensureToolIsLowered( vehicle, true )
	end
	
	return allowedToDrive
end

------------------------------------------------------------------------
-- checkIsAnimPlaying
------------------------------------------------------------------------
function AutoSteeringEngine.checkIsAnimPlaying( vehicle, moveDown )

	if vehicle.aseTools == nil or table.getn(vehicle.aseTools) < 1 then
		return false
	end
	
	for _,tool in pairs(vehicle.aseTools) do
		if tool.isPlough and tool.obj.rotationPart ~= nil then
			local self = tool.obj
      if self.rotationPart.turnAnimation ~= nil then
        do
          local turnAnimTime = self:getAnimationTime(self.rotationPart.turnAnimation)
          if turnAnimTime < self.rotationPart.touchAnimMaxLimit and turnAnimTime > self.rotationPart.touchAnimMinLimit then
						return true
          end
        end
      elseif self.rotationPart.node ~= nil then
        local x, y, z = getRotation(self.rotationPart.node)
        local maxRot = self.rotationPart.maxRot
        local minRot = self.rotationPart.minRot
        local eps = self.rotationPart.touchRotLimit
        if eps < math.abs(x - maxRot[1]) and eps < math.abs(x - minRot[1]) or eps < math.abs(y - maxRot[2]) and eps < math.abs(y - minRot[2]) or eps < math.abs(z - maxRot[3]) and eps < math.abs(z - minRot[3]) then
          return true
				end
      end
 		end
		if not moveDown and tool.specialType == "Packomat" and tool.obj.isRotating then
			return true
		end
		if moveDown and tool.lowerStateOnFruits == nil then
			if     tool.specialType == "Packomat"                     then
				if tool.obj.isRotating then
					return true
				elseif tool.acWaitUntilIsLowered == nil or tool.acWaitUntilIsLowered <= vehicle.time then
					if      tool.obj.ploughHasGroundContact     ~= moveDown then
						return true
					elseif  tool.aiTerrainDetailChannel3         < 0
							and tool.obj.cultivatorHasGroundContact ~= moveDown then
						return true
					end
				end
			elseif tool.obj.sowingMachineHasGroundContact ~= nil      then
				if   tool.obj.sowingMachineHasGroundContact ~= moveDown then return true end
			elseif tool.obj.ploughHasGroundContact        ~= nil      then
				if   		tool.obj.ploughHasGroundContact     ~= moveDown 
						and ( tool.acWaitUntilIsLowered == nil or tool.acWaitUntilIsLowered <= vehicle.time ) then
					return true 
				end
			elseif tool.obj.cultivatorHasGroundContact    ~= nil      then
				if   tool.obj.cultivatorHasGroundContact    ~= moveDown then return true end
			elseif tool.obj.isThreshing                   ~= nil      then
				if moveDown and not tool.obj.isThreshing then return true end
			elseif tool.obj.isTurnedOn                    ~= nil      then
				if moveDown and not tool.obj.isTurnedOn  then return true end
			elseif tool.obj.groundReferenceNode           ~= nil 
				 and tool.obj.groundReferenceThreshold      ~= nil      then
				local x, y, z = getWorldTranslation(tool.obj.groundReferenceNode)
				local terrainHeight = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, x, 0, z)
				if y <= terrainHeight + tool.obj.groundReferenceThreshold then			
					if not moveDown then return true end
				else
					if moveDown then return true end
				end
			elseif tool.acWaitUntilIsLowered ~= nil and tool.acWaitUntilIsLowered > vehicle.time then
				return true				
			end
		end
		
		--if			vehicle.isClient 
		--		and tool.obj.getIsAnimationPlaying ~= nil 
		--		and tool.obj.lowerAnimation        ~= nil then
		--	if tool.obj.getIsAnimationPlaying( tool.obj, tool.obj.lowerAnimation ) then
		--		return true
		--	end
		--	if tool.obj.foldingParts ~= nil and table.getn( tool.obj.foldingParts ) > 0 then
		--		for _, foldingPart in pairs(tool.obj.foldingParts) do
		--			if tool.obj.getIsAnimationPlaying( tool.obj, foldingPart.animationName ) then
		--				return true
		--			end
		--		end
		--	end
		--end
	end
	
	return false
end

------------------------------------------------------------------------
-- normalizeAngle
------------------------------------------------------------------------
function AutoSteeringEngine.normalizeAngle( b )
	local a = b
	while a >  math.pi do a = a - math.pi - math.pi end
	while a < -math.pi do a = a + math.pi + math.pi end
	return a
end

------------------------------------------------------------------------
-- getMaxSteeringAngle75
------------------------------------------------------------------------
function AutoSteeringEngine.getMaxSteeringAngle75( vehicle, invert )

	if     vehicle.aseDirectionBeforeTurn.turn75 == nil then
		vehicle.aseDirectionBeforeTurn.turn75 = {}
		
		local index   = AutoSteeringEngine.getNoReverseIndex( vehicle )
		local radius  = vehicle.aseChain.radius
		local radiusT = vehicle.aseChain.radius
		local alpha   = vehicle.aseChain.maxSteering
		local radiusE = vehicle.aseChain.radius
		local diffE   = 0
		local gammaE  = 0
		
		if index > 0 then
			local tan75Inv = 0.08748866 --0.267949192 -- 1 / math.tan( math.rad( 75 ) )
			local sin75Inv = 1.00381984 --1.03527618  -- 1 / math.sin( math.rad( 75 ) )
			
			local tool    = vehicle.aseTools[index]
			local r       = vehicle.aseChain.radius
			local _,_,b1  = AutoSteeringEngine.getRelativeTranslation( vehicle.aseChain.refNode, tool.refNode )
			b1            = math.max( 0, -b1 )
			local b2
			if tool.b2 == nil then
				b2          = math.max( 0, -tool.zb )
			else
				b2          = math.max( 0, -tool.b2 )
			end
			if b1 < 0 and b2 < -1 then
				b2 = b2 + 0.5
				b1 = b1 - 0.5
			end
						
			if vehicle.articulatedAxis == nil then
				radius = math.max( r, tan75Inv * b1 + sin75Inv * b2 )
			end
			radiusT  = math.sqrt( radius*radius + b1*b1 - b2*b2 )
			alpha    = math.min( vehicle.aseChain.maxSteering, math.atan( vehicle.aseChain.wheelBase / radius ) )
			radiusE  = r
			diffE    = 0.5 * math.max( 0, radiusE - radiusT )
			gammaE   = math.acos( math.min(math.max( 1 - diffE / radius, 0), 1 ) )
		end
						
		local diffT = vehicle.aseOtherX
		
		if invert then
			diffT = vehicle.aseActiveX
		else
			for i,tool in pairs(vehicle.aseTools) do
				if tool.isPlough or tool.specialType == "Packomat" then
					diffT = vehicle.aseActiveX
					break
				end
			end
		end		
		
		if diffT < 0 and ( vehicle.aseActiveX > 0 or vehicle.aseOtherX > 0 ) then -- vehicle.aseLRSwitch then
			diffT = -diffT
		end
		
		vehicle.aseDirectionBeforeTurn.turn75.index   = index 
		vehicle.aseDirectionBeforeTurn.turn75.radius  = radius
		vehicle.aseDirectionBeforeTurn.turn75.radiusT = radiusT
		vehicle.aseDirectionBeforeTurn.turn75.alpha   = alpha
		vehicle.aseDirectionBeforeTurn.turn75.diffE   = diffE  
		vehicle.aseDirectionBeforeTurn.turn75.gammaE  = gammaE
		vehicle.aseDirectionBeforeTurn.turn75.diffT   = diffT
	end
	
	return vehicle.aseDirectionBeforeTurn.turn75
end

------------------------------------------------------------------------
-- navigateToSavePoint
------------------------------------------------------------------------
function AutoSteeringEngine.navigateToSavePoint( vehicle, uTurn, fallback )

	if     vehicle.aseChain               == nil
			or vehicle.aseChain.maxSteering   == nil 
			or vehicle.aseDirectionBeforeTurn == nil then
		return 0, false
	end

	local angle   = nil
	local d1      = nil
	local onTrack = true
	local x0,y,z0 = getWorldTranslation( vehicle.aseChain.refNode );
	local x, z    = AutoSteeringEngine.getTurnVector( vehicle, uTurn )
	local a       = AutoSteeringEngine.normalizeAngle( math.pi - AutoSteeringEngine.getTurnAngle( vehicle )	)
	
	if     vehicle.aseDirectionBeforeTurn.targetTrace == nil
			or vehicle.aseDirectionBeforeTurn.targetTraceMode ~= 1 then
			
		vehicle.aseDirectionBeforeTurn.targetTrace       = {}			
		vehicle.aseDirectionBeforeTurn.targetTraceMode   = 1	
		vehicle.aseDirectionBeforeTurn.targetTraceRadius = 5
		vehicle.aseDirectionBeforeTurn.targetTraceA      = 0
		
		local p = {}
		if uTurn then
			p = {}
			p.x,_,p.z = localDirectionToWorld( vehicle.aseChain.headlandNode, vehicle.aseActiveX, 0, math.min( 0, vehicle.aseDistance ) - 5 )
			p.x = vehicle.aseDirectionBeforeTurn.x + p.x
			p.z = vehicle.aseDirectionBeforeTurn.z + p.z
			
			vehicle.aseDirectionBeforeTurn.targetTrace[1] = p
			vehicle.aseDirectionBeforeTurn.targetTraceMinZ = math.min( 0, vehicle.aseDistance ) - 4
			
			p = {}
			p.x,_,p.z = localDirectionToWorld( vehicle.aseChain.headlandNode, vehicle.aseActiveX, 0, math.min( 0, vehicle.aseDistance ) )
			p.x = vehicle.aseDirectionBeforeTurn.x + p.x
			p.z = vehicle.aseDirectionBeforeTurn.z + p.z
						
			vehicle.aseDirectionBeforeTurn.targetTrace[2] = p
		else
			
			p = {}

			if vehicle.aseLRSwitch then
				p.x,_,p.z = localDirectionToWorld( vehicle.aseChain.headlandNode, 0, 0, -vehicle.aseActiveX )
			else
				p.x,_,p.z = localDirectionToWorld( vehicle.aseChain.headlandNode, 0, 0,  vehicle.aseActiveX )
			end

			p.x = vehicle.aseDirectionBeforeTurn.x + p.x
			p.z = vehicle.aseDirectionBeforeTurn.z + p.z
			
			vehicle.aseDirectionBeforeTurn.targetTrace[1] = p				
		end
				
		if  		uTurn
				and z >= 1 
				and math.abs(x) >= 0.1
				and math.abs( a ) <= 0.75 * math.pi 
				and ( math.abs( a ) > 1E-3 or math.abs( x ) < 0.1 ) 
				and ( ( a >= 0 and x <= 0 ) or ( a <= 0 and x >= 0 ) ) then
			local r = 5
			local c = math.cos( a ) 
			local s = math.sin( a )
			local zo = 0
			local xo = vehicle.aseActiveX
			x = x - xo
			
			if z * ( 1 - c) < math.abs( x * s ) then
				r  = z / math.abs( s )
				if x < 0 then r = -r end
			--xo = xo + x - r * ( 1 - c )
			else
				r  = x / ( 1 - c )
				zo = zo + z - math.abs( r * s )
			end
			
			vehicle.aseDirectionBeforeTurn.targetTraceRadius = r
			vehicle.aseDirectionBeforeTurn.targetTraceX,   
			vehicle.aseDirectionBeforeTurn.targetTraceY,    
			vehicle.aseDirectionBeforeTurn.targetTraceZ = localDirectionToWorld( vehicle.aseChain.headlandNode, xo+r, 0, zo )
			vehicle.aseDirectionBeforeTurn.targetTraceX = vehicle.aseDirectionBeforeTurn.targetTraceX + vehicle.aseDirectionBeforeTurn.x
			vehicle.aseDirectionBeforeTurn.targetTraceZ = vehicle.aseDirectionBeforeTurn.targetTraceZ + vehicle.aseDirectionBeforeTurn.z
			vehicle.aseDirectionBeforeTurn.targetTraceA = -math.atan( vehicle.aseChain.wheelBase / r )
			
			local iMax = math.max( 2, math.floor( math.abs( a * r ) + 0.5 ) )
			
			for i=1,iMax do
				local aa = a * i / iMax
				local p = {}
		
				p.x,_,p.z = localDirectionToWorld( vehicle.aseChain.headlandNode, xo + r * (1-math.cos(aa)), 0, zo + math.abs( r * math.sin(aa) ) )
				p.x = vehicle.aseDirectionBeforeTurn.x + p.x
				p.z = vehicle.aseDirectionBeforeTurn.z + p.z
			
				vehicle.aseDirectionBeforeTurn.targetTrace[i+2] = p
			end		
		end
	end
	
	if      vehicle.aseDirectionBeforeTurn.targetTrace ~= nil 
			and z > vehicle.aseDirectionBeforeTurn.targetTraceMinZ then				
		local n = 0
		for i,p in pairs(vehicle.aseDirectionBeforeTurn.targetTrace) do
			local x,_,z = worldToLocal( vehicle.aseChain.refNode, p.x, y, p.z )
			if z > 1 then
				local d = x*x + z*z
				local a = math.atan( 2 * x * vehicle.aseChain.wheelBase / d )
				if math.abs(a) <= vehicle.aseChain.maxSteering then
					if i<=3 then
						n     = 1
						angle = a
					else
						n     = n + i-3
						angle = angle + (i-3) * a
					end
				end
			end
		end		
		if n > 1 then
			angle = angle / n
		end
	end
	
	if angle == nil then
		onTrack = false
		if vehicle.aseDirectionBeforeTurn.targetTrace ~= nil then		
			vehicle.aseDirectionBeforeTurn.targetTrace = nil
		end
		
		if fallback ~= nil then
			angle = fallback( vehicle, uTurn )
		else
			angle = 0
		end
	end
	
	angle = math.min( math.max( angle, -vehicle.aseChain.maxSteering  ), vehicle.aseChain.maxSteering  )
	
	return angle, onTrack
end

------------------------------------------------------------------------
-- setToolsAreTurnedOn
------------------------------------------------------------------------
function AutoSteeringEngine.setToolsAreTurnedOn( vehicle, isTurnedOn, immediate, objectFilter )
	if not AutoSteeringEngine.hasTools( vehicle ) then
		return
	end
	
	AutoSteeringEngine.setToolsAreLowered( vehicle, isTurnedOn, immediate, objectFilter )
	
	for i=1,table.getn( vehicle.aseTools ) do
		if objectFilter == nil or objectFilter == vehicle.aseTools[i].obj then
			local self = vehicle.aseTools[i].obj
			if     vehicle.aseTools[i].specialType == "Poettinger X8"          then
				local idx = self.x8.selectionIdx
				self:setSelection( 3 )
				if isTurnedOn then
					self:setTransport( false )
				end
				self:setTurnedOn( isTurnedOn )
				self:setSelection( idx )
			elseif vehicle.aseTools[i].specialType == "Poettinger AlphaMotion" then
				if isTurnedOn then
					self:setTransport( false )
				end
				self:setTurnedOn( isTurnedOn )
			elseif vehicle.aseTools[i].specialType == "Horsch SW3500 S"        then
			--if isTurnedOn and self.Go.trsp ~= isTurnedOn then
			--	self:setStateEvent("Speed", "trsp", 1.0)
			--	self:setStateEvent("Go", "trsp", isTurnedOn)
			--	self:setStateEvent("Done", "trsp", true)
			--end
				if self.turnOn ~= isTurnedOn then
					self:setStateEvent("turnOn", false, isTurnedOn)
				end
			elseif vehicle.aseTools[i].isCombine                               then
				self:setIsThreshing( isTurnedOn, true )
				self.waitingForDischarge       = false
				self.waitForDischargeTime      = 0
				self.waitingForTrailerToUnload = false
			elseif vehicle.aseTools[i].isAITool                                then
				if isTurnedOn then
					self:aiTurnOn()
				else
					self:aiTurnOff()
				end
			elseif self.setIsTurnedOn ~= nil then
				self:setIsTurnedOn(isTurnedOn, true)
			end
		end
	end
end

------------------------------------------------------------------------
-- setToolIsLowered
------------------------------------------------------------------------
function AutoSteeringEngine.setToolIsLowered( tool, isLowered )
	local self = tool.obj
	if     tool.isCombine                               then
		if isLowered then
			self:aiLower( )
		else
			self:aiRaise( )
		end
		if isLowered and not self.isThreshing then
			self:setIsThreshing( isLowered, true )
		end
	elseif tool.isSprayer                               then
		self:setIsTurnedOn( isLowered, true )
	elseif tool.specialType == "Poettinger X8"          then
		local idx = self.x8.selectionIdx
		self:setSelection( 3 )
		self:setLiftUp( not isLowered )
		self:setSelection( idx )
	elseif tool.specialType == "Poettinger AlphaMotion" then
		self:setLiftUp( not isLowered )
	elseif tool.specialType == "Taarup Mower"           then
		if self.setTransRot ~= nil then
			self:setTransRot( isLowered )
		end
		if      self.mowerFoldingParts ~= nil 
				and self.setIsArmDown      ~= nil then
			for k, part in pairs(self.mowerFoldingParts) do
				self:setIsArmDown( k, isLowered )
			end
		end
	elseif tool.specialType == "Horsch SW3500 S"        then
		if self.Go.down ~= isLowered then
			if isLowered then
				self:aiLower( )
			else
				self:aiRaise( )
			end
		end
	elseif self.aiLower ~= nil and self.aiRaise ~= nil then 
		if isLowered then
			self:aiLower( )
		else
			self:aiRaise( )
		end
	elseif self.setAIImplementsMoveDown ~= nil then
		self:setAIImplementsMoveDown( isLowered )
	end			
end

------------------------------------------------------------------------
-- setToolsAreLowered
------------------------------------------------------------------------
function AutoSteeringEngine.setToolsAreLowered( vehicle, isLowered, immediate, objectFilter )
	if not AutoSteeringEngine.hasTools( vehicle ) then
		return
	end
	
	local doItNow = false
	for i=1,table.getn( vehicle.aseTools ) do
		if      isLowered 
				and vehicle.aseTools[i].isCombine then
			doItNow = true
		end
		vehicle.aseTools[i].lowerStateOnFruits = isLowered
	end	
	if doItNow or immediate or objectFilter ~= nil then
		for i=1,table.getn( vehicle.aseToolParams ) do
			if     immediate
					or vehicle.aseTools[vehicle.aseToolParams[i].i].obj == objectFilter
					or ( isLowered
					 and vehicle.aseTools[vehicle.aseToolParams[i].i].isCombine 
					 and vehicle.aseTools[vehicle.aseToolParams[i].i].obj.lastValidInputFruitType == FruitUtil.FRUITTYPE_UNKNOWN ) then
				AutoSteeringEngine.ensureToolIsLowered( vehicle, isLowered, i )
			end
		end
	end
end

------------------------------------------------------------------------
-- setToolsAreLowered
------------------------------------------------------------------------
function AutoSteeringEngine.setPloughTransport( vehicle, isLowered, excludePackomat )
	if not AutoSteeringEngine.hasTools( vehicle ) then
		return
	end
	for i=1,table.getn( vehicle.aseTools ) do
		if      vehicle.aseTools[i].specialType == "Packomat"
				and ( excludePackomat == nil or not excludePackomat ) then
				
			self = vehicle.aseTools[i].obj
			if self.transport ~= isLowered then
				self:setStateEvent("transport", isLowered )
			end
		--elseif  vehicle.aseTools[i].isPlough 
		--	  and vehicle.aseTools[i].aiForceTurnNoBackward 
		--		and vehicle.aseTools[i].obj.setFoldState        ~= nil 
		--		and vehicle.aseTools[i].obj.turnOnFoldDirection ~= nil
		--		and vehicle.aseTools[i].obj.turnOnFoldDirection ~= 0 then
		--	self = vehicle.aseTools[i].obj
		--	if isLowered then
		--		self:setFoldDirection(self.turnOnFoldDirection, true)				
		--	else
		--		self:setFoldDirection(-self.turnOnFoldDirection, true)				
		--	end
		end
	end	
end

------------------------------------------------------------------------
-- ensureToolsLowered
------------------------------------------------------------------------
function AutoSteeringEngine.ensureToolIsLowered( vehicle, isLowered, indexFilter )
	if not AutoSteeringEngine.hasTools( vehicle ) then
		return
	end
	
	for i=1,table.getn( vehicle.aseToolParams ) do
		local doit = false
		if indexFilter == nil or indexFilter <= 0 then
			if vehicle.aseTools[vehicle.aseToolParams[i].i].lowerStateOnFruits ~= nil then
				doit = true
			end
		elseif i == indexFilter then
			if      vehicle.aseTools[vehicle.aseToolParams[i].i].lowerStateOnFruits ~= nil 
					and vehicle.aseTools[vehicle.aseToolParams[i].i].lowerStateOnFruits == isLowered then
				doit = true
			end
		end
		if doit then
			vehicle.aseTools[vehicle.aseToolParams[i].i].lowerStateOnFruits   = nil 
			vehicle.aseTools[vehicle.aseToolParams[i].i].acWaitUntilIsLowered = vehicle.time + vehicle.acDeltaTimeoutRun
			for _,implement in pairs(vehicle.attachedImplements) do
				if      implement.object == vehicle.aseTools[vehicle.aseToolParams[i].i].obj
						and ( implement.object.needsLowering or implement.object.aiNeedsLowering )
						then
					vehicle.setJointMoveDown( vehicle, implement.jointDescIndex, isLowered, true );
				end
			end
			AutoSteeringEngine.setToolIsLowered( vehicle.aseTools[vehicle.aseToolParams[i].i], isLowered )
		end
	end
	
	if indexFilter == nil or indexFilter <= 0 then
		for _,implement in pairs(vehicle.attachedImplements) do
			if implement.object ~= nil then
				local found = false
				for i=1,table.getn( vehicle.aseToolParams ) do
					if implement.object == vehicle.aseTools[vehicle.aseToolParams[i].i].obj then	
						found = true
						break
					end
				end
				if      not found
						and ( implement.object.needsLowering or implement.object.aiNeedsLowering )
						then
					vehicle.setJointMoveDown( vehicle, implement.jointDescIndex, isLowered, true );
				end
			end
		end
	end
end

------------------------------------------------------------------------
-- ensureToolsLowered
------------------------------------------------------------------------
function AutoSteeringEngine.findComponentJointDistance( vehicle, tool, object )
	
	if      object.attacherJoint              ~= nil
			and object.attacherJoint.jointType    ~= nil
			and ( object.attacherJoint.jointType  == Vehicle.JOINTTYPE_TRAILERLOW
			   or object.attacherJoint.jointType  == Vehicle.JOINTTYPE_TRAILER ) then
		return 0;
	end
	
	return -0.7;
end;

------------------------------------------------------------------------
-- Cultivator -> FrontPacker
------------------------------------------------------------------------
local ASEFrontPacker = {}

function AutoSteeringEngine.registerFrontPacker( cultivator )
 ASEFrontPacker[cultivator] = true
end

function AutoSteeringEngine.unregisterFrontPacker( cultivator )
 ASEFrontPacker[cultivator] = false
end

function AutoSteeringEngine.resetFrontPacker( vehicle )
	if vehicle == nil then
		ASEFrontPacker = {}
	elseif vehicle.attachedImplements ~= nil then
		for _, implement in pairs(vehicle.attachedImplements) do
			if implement.object ~= nil and ASEFrontPacker[implement.object] then
				AutoSteeringEngine.unregisterFrontPacker( implement.object )
				AutoSteeringEngine.resetFrontPacker( implement.object )
			end
		end
	end
end

function AutoSteeringEngine.hasFrontPacker( vehicle )
	if vehicle == nil or vehicle.attachedImplements == nil then 
		return false 
	end
	for _, implement in pairs(vehicle.attachedImplements) do
		if      implement.object ~= nil 
				and ( ASEFrontPacker[implement.object] 
					 or AutoSteeringEngine.hasFrontPacker( implement.object ) )then
			return true
		end
	end
	return false
end

function AutoSteeringEngine.updateTickCultivator( self, superFunc, ... )
	if ASEFrontPacker[self] then
		return FrontPacker.updateTick( self, ... )
	else
		return superFunc( self, ... )
	end
end
Cultivator.updateTick = Utils.overwrittenFunction( Cultivator.updateTick, AutoSteeringEngine.updateTickCultivator )


