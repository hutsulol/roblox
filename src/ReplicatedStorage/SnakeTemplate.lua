-- SnakeTemplate: Creates the snake model template stored in ReplicatedStorage
-- Called once during game initialization to build the template model

local GameConfig = require(script.Parent.GameConfig)

local SnakeTemplate = {}

function SnakeTemplate.createHeadPart()
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Size = GameConfig.HEAD_SIZE
	head.Shape = Enum.PartType.Ball
	head.Material = Enum.Material.SmoothPlastic
	head.TopSurface = Enum.SurfaceType.Smooth
	head.BottomSurface = Enum.SurfaceType.Smooth
	head.Anchored = true
	head.CanCollide = false

	-- Eyes for visual direction indication
	local leftEye = Instance.new("Part")
	leftEye.Name = "LeftEye"
	leftEye.Size = Vector3.new(0.6, 0.6, 0.6)
	leftEye.Shape = Enum.PartType.Ball
	leftEye.Material = Enum.Material.SmoothPlastic
	leftEye.Color = Color3.new(1, 1, 1)
	leftEye.Anchored = true
	leftEye.CanCollide = false
	leftEye.Parent = head

	local rightEye = leftEye:Clone()
	rightEye.Name = "RightEye"
	rightEye.Parent = head

	return head
end

function SnakeTemplate.createSegmentPart()
	local segment = Instance.new("Part")
	segment.Name = "Segment"
	segment.Size = GameConfig.SEGMENT_SIZE
	segment.Shape = Enum.PartType.Ball
	segment.Material = Enum.Material.SmoothPlastic
	segment.TopSurface = Enum.SurfaceType.Smooth
	segment.BottomSurface = Enum.SurfaceType.Smooth
	segment.Anchored = true
	segment.CanCollide = false
	return segment
end

function SnakeTemplate.createSnakeModel(color)
	local model = Instance.new("Model")
	model.Name = "Snake"

	local head = SnakeTemplate.createHeadPart()
	head.Color = color
	head.Parent = model
	model.PrimaryPart = head

	return model
end

return SnakeTemplate
