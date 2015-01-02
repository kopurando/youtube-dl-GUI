## Folder for downloads inside your homedir (will be created if missing),
## Note trailing slash!
set downloadsFolder to "Downloads/from youtube and others/"

## Explicit PATH declaration to assist locating ffprobe, ffmpeg etc.
set addPath to "PATH=$PATH:~/opt/bin:~/opt/sbin:/opt/local/bin:/opt/local/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

## arguments and path for youtube-dl
set ytCmd to "/usr/local/bin/youtube-dl"
set ytArgs to " --no-part --ignore-errors --no-overwrites -o '%(title)s - %(extractor)s_%(id)s.%(ext)s' --no-mtime "

#if youtube-dl not installed, use pre-packaged file
tell application "System Events" to set ytdlInstalled to exists disk item (my POSIX file ytCmd as string)
if not ytdlInstalled then
	set objectFolder to POSIX path of ((path to me as text) & "::")
	set ytCmd to quoted form of (POSIX path of (objectFolder) & "youtube-dl")
end if

set dnPwd to quoted form of (POSIX path of (path to home folder) & downloadsFolder)
set extractAudio to ""

try
	## create downloads folder (if missing)
	do shell script "[ -d " & dnPwd & " ] || mkdir " & dnPwd
	
	## grab URL of the frontmost Chrome or Safari window/tab 
	tell application "System Events" to set frontApp to name of first process whose frontmost is true
	
	if (frontApp = "Safari") or (frontApp = "Webkit") then
		using terms from application "Safari"
			tell application frontApp to set theURL to URL of front document
		end using terms from
	else if (frontApp = "Google Chrome") or (frontApp = "Google Chrome Canary") or (frontApp = "Chromium") then
		using terms from application "Google Chrome"
			tell application frontApp to set theURL to URL of active tab of front window
		end using terms from
	else
		tell application "Google Chrome"
			set theURL to URL of active tab of front window as string
		end tell
	end if
	
	## if URL is not recognized/supported, try updating youtube-dl
	set validURL to false
	repeat while not validURL
		display notification theURL with title "Checking URL (you can close tab now)" subtitle "download will start in background"
		
		try
			## get video filename for further checks
			set fileName to do shell script ytCmd & ytArgs & " --get-filename " & quoted form of theURL
			set validURL to true
			
		on error errorMessage number errorNumber
			if errorNumber is 1 then
				display alert theURL as warning message "Media from this URL can't be downloaded or youtube-dl needs to be updated. 
			
Would you like to update now? Admin password will be required." buttons {"Update youtube-dl", "Quit"} default button 2
				set answer to button returned of result
				if answer is equal to "Quit" then
					return -128
				else if answer is equal to "Update youtube-dl" then
					try
						set updateResult to do shell script ytCmd & " -U" with administrator privileges
						display alert updateResult buttons {"Retry media download"}
						
					on error errorMessage number errorNumber
						display dialog errorMessage with title "youtube-dl update FAILED" with icon stop buttons {"Quit"} default button 1
						set answer to button returned of result
						if answer is equal to "Quit" then
							return -128
						end if
					end try
				end if
			end if
		end try
	end repeat
	
	## do not ask download type for audio-files (soundcloud, mixcloud etc)
	set audioFile to do shell script "echo " & quoted form of fileName & " | grep -qEi '.(mp4|flv|wmv|mov|avi|mpeg|mpg|m4v|mkv|divx|asf)$'; echo $?"
	if audioFile is "0" then
		display dialog "Ready to download " & fileName & "
		
Please select download mode:" with title "virga" with icon note buttons {"MP3-audio only", "Video", "Video + extract audio"} default button 2
		set answer to button returned of result
		if answer is equal to "MP3-audio only" then
			set extractAudio to " --extract-audio --audio-format mp3 --audio-quality 0 "
			display notification fileName with title "🎶 Extracting audio " subtitle "Check downloads folder for progress..."
		else if answer is equal to "Video + extract audio" then
			set extractAudio to " --extract-audio --keep-video "
			display notification fileName with title "⬇️ Downloading video + audio " subtitle "Check downloads folder for progress..."
		else
			display notification fileName with title "⬇️ Downloading video " subtitle "Check downloads folder for progress..."
		end if
	else
		display notification fileName with title "⬇️ Downloading media " subtitle "Check downloads folder for progress..."
	end if
	
	try
		do shell script addPath & "; cd " & dnPwd & " && " & ytCmd & ytArgs & extractAudio & quoted form of theURL
		display notification fileName with title "✅ Finished downloading" subtitle " -> " & downloadsFolder sound name "Pop"
	on error errorMessage number errorNumber
		display notification errorMessage with title "❌ DOWNLOAD FAILED" subtitle theURL
	end try
	
end try
