--!strict
-- Creates ReplicatedStorage.Remotes (CLAUDE.md §4.3). Safe to call more than once.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type Remotes = {
	GetProgress: RemoteFunction,
	ProgressChanged: RemoteEvent,
	ReportLesson: RemoteEvent,
	SaveSettings: RemoteEvent,
}

local Remotes = {}

local cached: Remotes? = nil

local function ensure(folder: Folder, className: string, name: string): any
	local existing = folder:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local remote = Instance.new(className)
	remote.Name = name
	remote.Parent = folder
	return remote
end

function Remotes.create(): Remotes
	if cached then
		return cached
	end

	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not (folder and folder:IsA("Folder")) then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
	end
	local remotesFolder = folder :: Folder

	local remotes: Remotes = {
		GetProgress = ensure(remotesFolder, "RemoteFunction", "GetProgress"),
		ProgressChanged = ensure(remotesFolder, "RemoteEvent", "ProgressChanged"),
		ReportLesson = ensure(remotesFolder, "RemoteEvent", "ReportLesson"),
		SaveSettings = ensure(remotesFolder, "RemoteEvent", "SaveSettings"),
	}
	-- Parent last so clients never see a half-filled folder.
	remotesFolder.Parent = ReplicatedStorage

	cached = remotes
	return remotes
end

return Remotes
