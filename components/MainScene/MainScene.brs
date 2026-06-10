sub init()
    m.top.backgroundURI = "pkg:/images/background-controls.jpg"

    m.save_feed_url = m.top.FindNode("save_feed_url")
    m.get_channel_list = m.top.FindNode("get_channel_list")
    m.get_channel_list.ObserveField("content", "SetContent")
    
    m.playlistList = m.top.FindNode("playlistList")
    m.playlistList.ObserveField("itemSelected", "onPlaylistSelected")
    
    m.channelList = m.top.FindNode("channelList")
    m.channelList.ObserveField("itemSelected", "onChannelSelected")
    m.channelList.ObserveField("itemFocused", "onChannelFocused")
    
    m.sidePanel = m.top.FindNode("sidePanel")
    m.loadingSpinner = m.top.FindNode("loadingSpinner")
    
    m.channelOverlay = m.top.FindNode("channelOverlay")
    m.channelOverlayList = m.top.FindNode("channelOverlayList")
    m.channelOverlayList.ObserveField("itemSelected", "onOverlayChannelSelected")
    
    m.channelInfoOverlay = m.top.FindNode("channelInfoOverlay")
    m.channelInfoLabel = m.top.FindNode("channelInfoLabel")
    
    ' Vista previa del video
    m.previewContainer = m.top.FindNode("previewContainer")
    m.previewVideo = m.top.FindNode("PreviewVideo")
    m.previewChannelName = m.top.FindNode("previewChannelName")
    
    if m.previewVideo <> invalid then
        m.previewVideo.EnableCookies()
        m.previewVideo.SetCertificatesFile("common:/certs/ca-bundle.crt")
        m.previewVideo.InitClientCertificates()
    end if
    
    if m.loadingSpinner <> invalid then
        m.loadingSpinner.visible = false
    end if

    m.video = m.top.FindNode("Video")
    m.video.ObserveField("state", "checkState")
    
    m.allChannels = invalid
    m.flatChannelList = []
    m.currentChannelIndex = 0
    m.previewChannelIndex = -1
    m.playlists = []
    m.currentPlaylist = 0
    m.isPlayingVideo = false
    m.overlayVisible = false
    m.lastFocusedChannel = -1
    m.pendingChannelUrl = invalid
    
    loadSavedPlaylists()
    setupPlaylistMenu()
    
    ' Load the last saved state
    lastState = loadLastState()
    
    if m.playlists.Count() > 0 then
        ' Use the last playlist if it exists; otherwise, use the first one.
        playlistIndex = 0
        if lastState.playlistIndex <> invalid and lastState.playlistIndex >= 0 and lastState.playlistIndex < m.playlists.Count() then
            playlistIndex = lastState.playlistIndex
        end if
        
        m.currentPlaylist = playlistIndex
        m.playlistList.jumpToItem = playlistIndex
        
        ' Keep the last channel URL so it can be selected again after loading.
        if lastState.channelUrl <> invalid and lastState.channelUrl <> "" then
            m.pendingChannelUrl = lastState.channelUrl
        end if
        
        loadPlaylist(m.playlists[playlistIndex].url)
    else
        showPlaylistManager()
    end if
    
    ' Signal that the app launch is complete and UI is ready
    m.top.signalBeacon("AppLaunchComplete")
End sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    print ">>> KEYEVENT: key = '"; key; "', press = "; press; ", isPlayingVideo = "; m.isPlayingVideo
    result = false
    
    if(press)
        if m.isPlayingVideo then
            if(key = "back")
                m.video.control = "stop"
                m.video.visible = false
                m.channelOverlay.visible = false
                m.channelList.visible = true
                m.sidePanel.visible = true
                m.previewContainer.visible = true
                m.isPlayingVideo = false
                m.overlayVisible = false
                m.channelList.SetFocus(true)
                m.top.backgroundURI = "pkg:/images/background-controls.jpg"
                
                ' Continue preview playback if a channel is focused
                if m.lastFocusedChannel >= 0 then
                    playPreviewChannel(m.lastFocusedChannel)
                end if
                result = true
            else if(key = "left")
                print ">>> OVERLAY: Left arrow key pressed"
                print ">>> OVERLAY: overlayVisible = "; m.overlayVisible
                print ">>> OVERLAY: allChannels = "; m.allChannels
                
                if m.overlayVisible then
                    print ">>> OVERLAY: Hiding overlay"
                    m.channelOverlay.visible = false
                    m.overlayVisible = false
                    m.top.setFocus(true)
                else
                    print ">>> OVERLAY: Showing overlay"
                    if m.allChannels <> invalid then
                        m.channelOverlay.visible = true
                        m.overlayVisible = true
                        m.channelOverlayList.content = m.allChannels
                        m.channelOverlayList.jumpToItem = m.currentChannelIndex
                        m.channelOverlayList.SetFocus(true)
                        print ">>> OVERLAY: Overlay visible, channels loaded"
                    else
                        print ">>> OVERLAY ERROR: No channels available (m.allChannels are invalid)"
                    end if
                end if
                result = true
            else if(key = "right" and m.overlayVisible)
                m.channelOverlay.visible = false
                m.overlayVisible = false
                m.top.setFocus(true)
                result = true
            else if(key = "up" or key = "rewind")
                print ">>> KEY UP/RW presionado, overlayVisible = "; m.overlayVisible
                if not m.overlayVisible then
                    print ">>> KEY UP: Executing changeChannel(-1)"
                    changeChannel(-1)
                    result = true
                else
                    print ">>> KEY UP: Overlay visible, input passed to overlay"
                end if
            else if(key = "down" or key = "fastforward")
                print ">>> KEY DOWN/FF presionado, overlayVisible = "; m.overlayVisible
                if not m.overlayVisible then
                    print ">>> KEY DOWN: Executing changeChannel(1)"
                    changeChannel(1)
                    result = true
                else
                    print ">>> KEY DOWN: Overlay visible, input passed to overlay"
                end if
            else if(key = "OK")
                ' Display the options menu only when the video is already playing
                if m.video.state = "playing" or m.video.state = "paused" or m.video.state = "buffering" then
                    showVideoOptionsMenu()
                    result = true
                end if
            else if(key = "play")
                ' Play/Pause the video
                if m.video.state = "playing" then
                    m.video.control = "pause"
                else
                    m.video.control = "resume"
                end if
                result = true
            else if(key = "replay")
                ' Reload the current channel (Instant Replay)
                reloadCurrentChannel()
                result = true
            end if
        else
            if(key = "right")
                m.sidePanel.visible = true
                m.channelList.SetFocus(true)
                result = true
            else if(key = "left")
                m.sidePanel.visible = true
                m.playlistList.SetFocus(true)
                result = true
            else if(key = "options")
                if m.playlistList.hasFocus() then
                    showPlaylistOptions()
                else
                    showPlaylistManager()
                end if
                result = true
            else if(key = "replay")
                if m.playlistList.hasFocus() then
                    showPlaylistOptions()
                    result = true
                end if
            end if
        end if
    end if
    
    return result 
end function

sub loadSavedPlaylists()
    reg = CreateObject("roRegistrySection", "playlists")
    m.playlists = []
    
    m.playlists.Push({
        name: "Grizz",
        url: "https://grizz.atwebpages.com/grizz.m3u",
        isDefault: true
    })

    m.playlists.Push({
        name: "United States",
        url: "https://iptv-org.github.io/iptv/countries/us.m3u",
        isDefault: true
    })

    m.playlists.Push({
        name: "Canada",
        url: "https://iptv-org.github.io/iptv/countries/ca.m3u",
        isDefault: true
    })

    m.playlists.Push({
        name: "United Kingdom",
        url: "https://iptv-org.github.io/iptv/countries/uk.m3u",
        isDefault: true
    })

    m.playlists.Push({
        name: "Australia",
        url: "https://iptv-org.github.io/iptv/countries/au.m3u",
        isDefault: true
    })
    
    if reg.Exists("count") then
        count = reg.Read("count").ToInt()
        for i = 0 to count - 1
            name = reg.Read("name_" + i.ToStr())
            url = reg.Read("url_" + i.ToStr())
            if name <> invalid and url <> invalid then
                m.playlists.Push({name: name, url: url, isDefault: false})
            end if
        end for
    end if
end sub

sub savePlaylist(name as String, url as String)
    reg = CreateObject("roRegistrySection", "playlists")
    
    count = 0
    if reg.Exists("count") then
        count = reg.Read("count").ToInt()
    end if
    
    reg.Write("name_" + count.ToStr(), name)
    reg.Write("url_" + count.ToStr(), url)
    reg.Write("count", (count + 1).ToStr())
    reg.Flush()
    
    m.playlists.Push({name: name, url: url, isDefault: false})
    setupPlaylistMenu()
end sub

sub loadPlaylist(url as String)
    m.global.feedurl = url
    
    if m.loadingSpinner <> invalid then
        m.loadingSpinner.visible = true
    end if
    
    m.get_channel_list.control = "RUN"
end sub

sub setupPlaylistMenu()
    content = CreateObject("roSGNode", "ContentNode")
    
    countryFlags = {
        "Colombia": "🇨🇴",
        "Chile": "🇨🇱",
        "Argentina": "🇦🇷",
        "Mexico": "🇲🇽",
        "Ecuador": "🇪🇨",
        "United States": "🇺🇸",
        "Canada": "🇨🇦",
        "Australia": "🇦🇺",
        "United Kingdom": "🇬🇧",
        "Japan": "🇯🇵",
        "Korea": "🇰🇷"
    }
    
    for each playlist in m.playlists
        item = content.CreateChild("ContentNode")
        if playlist.isDefault = true then
            flag = countryFlags[playlist.name]
            if flag <> invalid then
                item.title = flag + " " + playlist.name
            else
                item.title = "⭐ " + playlist.name
            end if
        else
            item.title = "📺 " + playlist.name
        end if
    end for
    
    item = content.CreateChild("ContentNode")
    item.title = "➕ Add new playlist"
    
    m.playlistList.content = content
    m.playlistList.SetFocus(true)
end sub

sub onPlaylistSelected()
    selectedIdx = m.playlistList.itemSelected
    
    if selectedIdx = m.playlists.Count() then
        showPlaylistManager()
    else if selectedIdx >= 0 and selectedIdx < m.playlists.Count() then
        m.currentPlaylist = selectedIdx
        m.pendingChannelUrl = invalid ' Clear queued channel when changing playlist
        loadPlaylist(m.playlists[selectedIdx].url)
        
        ' Save the selected playlist
        saveLastState()
    end if
end sub

sub showPlaylistOptions()
    selectedIdx = m.playlistList.itemSelected
    
    if selectedIdx < 0 or selectedIdx >= m.playlists.Count() then
        return
    end if
    
    selectedPlaylist = m.playlists[selectedIdx]
    
    if selectedPlaylist.isDefault = true then
        dialog = CreateObject("roSGNode", "Dialog")
        dialog.title = selectedPlaylist.name
        dialog.message = "Built-in playlists cannot be edited or removed."
        dialog.buttons = ["OK"]
        m.top.dialog = dialog
        m.top.dialog.observeField("buttonSelected", "onDefaultPlaylistDialogClosed")
        return
    end if
    
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Opciones: " + selectedPlaylist.name
    dialog.buttons = ["Edit Name", "Edit URL", "Delete", "Cancel"]
    m.top.dialog = dialog
    m.selectedPlaylistIndex = selectedIdx
    
    m.top.dialog.observeField("buttonSelected", "onPlaylistOptionSelected")
end sub

sub onDefaultPlaylistDialogClosed()
    m.top.dialog.unobserveField("buttonSelected")
    m.top.dialog.close = true
    m.playlistList.setFocus(true)
end sub

sub onPlaylistOptionSelected()
    buttonIdx = m.top.dialog.buttonSelected
    
    m.top.dialog.unobserveField("buttonSelected")
    m.top.dialog.close = true
    
    if buttonIdx = 0 then
        ' Use a timer to wait for the dialog to close.
        m.optionTimer = CreateObject("roSGNode", "Timer")
        m.optionTimer.duration = 0.2
        m.optionTimer.repeat = false
        m.optionTimer.observeField("fire", "editPlaylistName")
        m.optionTimer.control = "start"
    else if buttonIdx = 1 then
        m.optionTimer = CreateObject("roSGNode", "Timer")
        m.optionTimer.duration = 0.2
        m.optionTimer.repeat = false
        m.optionTimer.observeField("fire", "editPlaylistUrl")
        m.optionTimer.control = "start"
    else if buttonIdx = 2 then
        m.optionTimer = CreateObject("roSGNode", "Timer")
        m.optionTimer.duration = 0.2
        m.optionTimer.repeat = false
        m.optionTimer.observeField("fire", "confirmDeletePlaylist")
        m.optionTimer.control = "start"
    else
        m.playlistList.setFocus(true)
    end if
end sub

sub editPlaylistName()
    print ">>> EDIT NAME: Initializing"
    
    ' Clear timer if it exists
    if m.optionTimer <> invalid then
        m.optionTimer.unobserveField("fire")
        m.optionTimer = invalid
    end if
    
    if m.selectedPlaylistIndex = invalid then return
    
    playlist = m.playlists[m.selectedPlaylistIndex]
    
    keyboard = createObject("roSGNode", "StandardKeyboardDialog")
    keyboard.backgroundUri = "pkg:/images/rsgde_bg_hd.jpg"
    keyboard.title = "EDIT NAME"
    keyboard.message = "Enter new name for playlist"
    keyboard.text = playlist.name
    keyboard.buttons = ["Save", "Cancel"]
    
    m.top.dialog = keyboard
    m.top.dialog.observeField("buttonSelected", "onEditNameComplete")
end sub

sub onEditNameComplete()
    print ">>> EDIT NAME: buttonSelected = "; m.top.dialog.buttonSelected
    
    buttonSelected = m.top.dialog.buttonSelected
    
    if buttonSelected = 0 then
        newName = m.top.dialog.text
        
        ' Unregister and close the dialog
        m.top.dialog.unobserveField("buttonSelected")
        m.top.dialog.close = true
        
        if newName <> "" and newName <> invalid then
            playlist = m.playlists[m.selectedPlaylistIndex]
            playlist.name = newName
            
            reg = CreateObject("roRegistrySection", "playlists")
            regIndex = m.selectedPlaylistIndex - 6
            if regIndex >= 0 then
                reg.Write("name_" + regIndex.ToStr(), newName)
                reg.Flush()
            end if
            
            setupPlaylistMenu()
        end if
    else
        m.top.dialog.unobserveField("buttonSelected")
        m.top.dialog.close = true
    end if
    
    m.playlistList.setFocus(true)
end sub

sub editPlaylistUrl()
    print ">>> EDIT URL: Initializing"
    
    ' Clear time if exists
    if m.optionTimer <> invalid then
        m.optionTimer.unobserveField("fire")
        m.optionTimer = invalid
    end if
    
    if m.selectedPlaylistIndex = invalid then return
    
    playlist = m.playlists[m.selectedPlaylistIndex]
    
    keyboard = createObject("roSGNode", "StandardKeyboardDialog")
    keyboard.backgroundUri = "pkg:/images/rsgde_bg_hd.jpg"
    keyboard.title = "EDIT URL"
    keyboard.message = "New URL for the M3U playlist"
    keyboard.text = playlist.url
    keyboard.buttons = ["Save", "Cancel"]
    
    m.top.dialog = keyboard
    m.top.dialog.observeField("buttonSelected", "onEditUrlComplete")
end sub

sub onEditUrlComplete()
    print ">>> EDIT URL: buttonSelected = "; m.top.dialog.buttonSelected
    
    buttonSelected = m.top.dialog.buttonSelected
    
    if buttonSelected = 0 then
        newUrl = m.top.dialog.text
        
        ' Unregister and close the dialog first
        m.top.dialog.unobserveField("buttonSelected")
        m.top.dialog.close = true
        
        if isValidUrl(newUrl) then
            playlist = m.playlists[m.selectedPlaylistIndex]
            playlist.url = newUrl
            
            reg = CreateObject("roRegistrySection", "playlists")
            regIndex = m.selectedPlaylistIndex - 6
            if regIndex >= 0 then
                reg.Write("url_" + regIndex.ToStr(), newUrl)
                reg.Flush()
            end if
            
            loadPlaylist(newUrl)
        else
            ' Show error
            m.pendingErrorMessage = "URL invalid. Must start with http:// or https://"
            m.editUrlErrorTimer = CreateObject("roSGNode", "Timer")
            m.editUrlErrorTimer.duration = 0.3
            m.editUrlErrorTimer.repeat = false
            m.editUrlErrorTimer.observeField("fire", "showEditUrlError")
            m.editUrlErrorTimer.control = "start"
        end if
    else
        m.top.dialog.unobserveField("buttonSelected")
        m.top.dialog.close = true
        m.playlistList.setFocus(true)
    end if
end sub

sub showEditUrlError()
    print ">>> EDIT URL ERROR: Showing error dialog"
    
    if m.editUrlErrorTimer <> invalid then
        m.editUrlErrorTimer.unobserveField("fire")
        m.editUrlErrorTimer = invalid
    end if
    
    errorDialog = CreateObject("roSGNode", "Dialog")
    errorDialog.title = "Error"
    errorDialog.message = "URL invalid Must start with http:// or https://"
    errorDialog.buttons = ["OK"]
    
    m.top.dialog = errorDialog
    m.top.dialog.observeField("buttonSelected", "onEditUrlErrorClosed")
end sub

sub onEditUrlErrorClosed()
    m.top.dialog.unobserveField("buttonSelected")
    m.top.dialog.close = true
    m.playlistList.setFocus(true)
end sub

sub confirmDeletePlaylist()
    print ">>> DELETE: Showing confirmation"
    
    ' Clear timer if it exists
    if m.optionTimer <> invalid then
        m.optionTimer.unobserveField("fire")
        m.optionTimer = invalid
    end if
    
    if m.selectedPlaylistIndex = invalid then return
    
    playlist = m.playlists[m.selectedPlaylistIndex]
    
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "Are you sure?"
    dialog.message = "Delete '" + playlist.name + "'?"
    dialog.buttons = ["Delete", "Cancel"]
    
    m.top.dialog = dialog
    m.top.dialog.observeField("buttonSelected", "onDeleteConfirmed")
end sub

sub onDeleteConfirmed()
    print ">>> DELETE: buttonSelected = "; m.top.dialog.buttonSelected
    
    buttonSelected = m.top.dialog.buttonSelected
    
    m.top.dialog.unobserveField("buttonSelected")
    m.top.dialog.close = true
    
    if buttonSelected = 0 then
        regIndex = m.selectedPlaylistIndex - 6
        
        m.playlists.Delete(m.selectedPlaylistIndex)
        
        reg = CreateObject("roRegistrySection", "playlists")
        
        newIndex = 0
        for i = 6 to m.playlists.Count() - 1
            pl = m.playlists[i]
            if pl.isDefault = false then
                reg.Write("name_" + newIndex.ToStr(), pl.name)
                reg.Write("url_" + newIndex.ToStr(), pl.url)
                newIndex = newIndex + 1
            end if
        end for
        
        reg.Write("count", newIndex.ToStr())
        reg.Flush()
        
        setupPlaylistMenu()
        
        if m.playlists.Count() > 0 then
            loadPlaylist(m.playlists[0].url)
        end if
    end if
    
    m.playlistList.setFocus(true)
end sub

sub showPlaylistManager()
    print ">>> PLAYLIST MANAGER: Starting step one: NAME <<<"
    
    ' Clear previous dialogs
    if m.top.dialog <> invalid then
        m.top.dialog.close = true
        m.top.dialog = invalid
    end if
    
    ' Clear previous timers
    if m.urlDialogTimer <> invalid then
        m.urlDialogTimer.control = "stop"
        m.urlDialogTimer = invalid
    end if
    
    m.tempPlaylistName = invalid
    
    keyboardDialog = createObject("roSGNode", "StandardKeyboardDialog")
    keyboardDialog.backgroundUri = "pkg:/images/rsgde_bg_hd.jpg"
    keyboardDialog.title = "NEW PLAYLIST - STEP 1/2"
    keyboardDialog.message = "Enter name (ex: My list)"
    keyboardDialog.buttons = ["Next", "Cancel"]
    keyboardDialog.text = ""
    
    m.top.dialog = keyboardDialog
    m.top.dialog.observeField("buttonSelected", "onPlaylistNameEntered")
    
    print ">>> PLAYLIST MANAGER: Showing NAME dialog"
end sub

sub onPlaylistNameEntered()
    print ">>> PLAYLIST NAME: buttonSelected = "; m.top.dialog.buttonSelected
    
    buttonSelected = m.top.dialog.buttonSelected
    
    if buttonSelected = 0 then
        ' "Next" button pressed
        name = m.top.dialog.text
        if name = "" or name = invalid then
            name = "New Playlist"
        end if
        
        m.tempPlaylistName = name
        print ">>> PLAYLIST NAME: Name saved = "; m.tempPlaylistName
        
        ' Close current dialog
        m.top.dialog.unobserveField("buttonSelected")
        m.top.dialog.close = true
        
        ' Wait a moment before showing the next dialog
        m.urlDialogTimer = CreateObject("roSGNode", "Timer")
        m.urlDialogTimer.duration = 0.3
        m.urlDialogTimer.repeat = false
        m.urlDialogTimer.observeField("fire", "showUrlDialog")
        m.urlDialogTimer.control = "start"
    else
        ' "Cancel" button pressed
        print ">>> PLAYLIST NAME: Cancel"
        m.top.dialog.unobserveField("buttonSelected")
        m.top.dialog.close = true
        m.tempPlaylistName = invalid
        
        ' Restore focus to the list
        m.playlistList.setFocus(true)
    end if
end sub

sub showUrlDialog()
    print ">>> URL DIALOG: Starting part 2 - URL <<<"
    
    ' Clear timer
    if m.urlDialogTimer <> invalid then
        m.urlDialogTimer.unobserveField("fire")
        m.urlDialogTimer = invalid
    end if
    
    ' Check if name already exists
    if m.tempPlaylistName = invalid then
        print ">>> URL DIALOG ERROR: No name saved"
        m.playlistList.setFocus(true)
        return
    end if
    
    urlDialog = createObject("roSGNode", "StandardKeyboardDialog")
    urlDialog.backgroundUri = "pkg:/images/rsgde_bg_hd.jpg"
    urlDialog.title = "NEW PLAYLIST - PART 2/2"
    urlDialog.message = "URL of the M3U playlist (ex: https://example.com/list.m3u)"
    urlDialog.buttons = ["Add", "Cancel"]
    urlDialog.text = ""
    
    m.top.dialog = urlDialog
    m.top.dialog.observeField("buttonSelected", "onPlaylistUrlEntered")
    
    print ">>> URL DIALOG: URL dialog displayed"
end sub

sub onPlaylistUrlEntered()
    print ">>> PLAYLIST URL: buttonSelected = "; m.top.dialog.buttonSelected
    
    buttonSelected = m.top.dialog.buttonSelected
    
    if buttonSelected = 0 then
        ' "Add" button pressed
        url = m.top.dialog.text
        print ">>> PLAYLIST URL: URL entered = "; url
        
        ' Remove observer and close dialog
        m.top.dialog.unobserveField("buttonSelected")
        m.top.dialog.close = true
        
        ' Validar URL
        if url = "" or url = invalid then
            print ">>> PLAYLIST URL ERROR: URL vacía"
            showUrlErrorMessage("La URL no puede estar vacía")
            return
        end if
        
        if not isValidUrl(url) then
            print ">>> PLAYLIST URL ERROR: URL empty"
            showUrlErrorMessage("URL invalid. Must start with http:// or https://")
            return
        end if
        
        ' Save and load the playlist
        if m.tempPlaylistName <> invalid then
            print ">>> PLAYLIST URL: Saving playlist - Name: "; m.tempPlaylistName; ", URL: "; url
            savePlaylist(m.tempPlaylistName, url)
            loadPlaylist(url)
        end if
        
        m.tempPlaylistName = invalid
        m.playlistList.setFocus(true)
    else
        ' Cancel button pressed
        print ">>> PLAYLIST URL: Canceled"
        m.top.dialog.unobserveField("buttonSelected")
        m.top.dialog.close = true
        m.tempPlaylistName = invalid
        m.playlistList.setFocus(true)
    end if
end sub

sub showUrlErrorMessage(message as String)
    print ">>> URL ERROR: Displaying error message"
    
    ' Use a timer to show the error
    m.pendingErrorMessage = message
    m.errorTimer = CreateObject("roSGNode", "Timer")
    m.errorTimer.duration = 0.3
    m.errorTimer.repeat = false
    m.errorTimer.observeField("fire", "showUrlError")
    m.errorTimer.control = "start"
end sub

sub showUrlError()
    print ">>> URL ERROR: Timer triggered, showing dialog"
    
    if m.errorTimer <> invalid then
        m.errorTimer.unobserveField("fire")
        m.errorTimer = invalid
    end if
    
    message = "URL invalid. Must start with http:// or https://"
    if m.pendingErrorMessage <> invalid then
        message = m.pendingErrorMessage
        m.pendingErrorMessage = invalid
    end if
    
    errorDialog = CreateObject("roSGNode", "Dialog")
    errorDialog.title = "Error"
    errorDialog.message = message
    errorDialog.buttons = ["OK"]
    
    m.top.dialog = errorDialog
    m.top.dialog.observeField("buttonSelected", "onErrorDialogClosed")
end sub

sub onErrorDialogClosed()
    print ">>> ERROR DIALOG: Closed"
    m.top.dialog.unobserveField("buttonSelected")
    m.top.dialog.close = true
    m.playlistList.setFocus(true)
end sub

sub checkState()
    state = m.video.state
    if(state = "error")
        ' Show error in overlay rather than a blocking dialog
        showChannelError(m.video.errorMsg)
    end if
end sub

sub showChannelError(errorMsg as String)
    if m.channelInfoOverlay = invalid or m.channelInfoLabel = invalid then return
    
    channelNumber = (m.currentChannelIndex + 1).ToStr()
    totalChannels = m.flatChannelList.Count().ToStr()
    
    channel = m.flatChannelList[m.currentChannelIndex]
    channelName = "Channel"
    if channel <> invalid and channel.title <> invalid then
        channelName = channel.title
    end if
    
    m.channelInfoLabel.text = channelNumber + "/" + totalChannels + " - " + channelName + chr(10) + "⚠️ Error: Channel unavailable"
    
    m.channelInfoOverlay.visible = true
    
    ' Set a timer to hide the overlay after 4 seconds
    if m.channelInfoTimer <> invalid then
        m.channelInfoTimer.control = "stop"
    end if
    
    m.channelInfoTimer = CreateObject("roSGNode", "Timer")
    m.channelInfoTimer.duration = 4
    m.channelInfoTimer.repeat = false
    m.channelInfoTimer.ObserveField("fire", "hideChannelInfo")
    m.channelInfoTimer.control = "start"
end sub

sub SetContent()
    if m.loadingSpinner <> invalid then
        m.loadingSpinner.visible = false
    end if
    
    if m.get_channel_list.content <> invalid then
        m.allChannels = m.get_channel_list.content
        buildFlatChannelList()
        
        if m.flatChannelList.Count() > 0 and m.currentChannelIndex = 0 then
            m.currentChannelIndex = 0
            print ">>> SETCONTENT: Initializing currentChannelIndex = 0"
        end if
        
        m.channelList.content = m.allChannels
        m.channelList.SetFocus(true)
        
        ' Resume last channel if one is pending
        restorePendingChannel()
    else
        errorDialog = CreateObject("roSGNode", "Dialog")
        errorDialog.title = "Error"
        errorDialog.message = "Could not load the list. Check URL."
        m.top.dialog = errorDialog
    end if
end sub

sub buildFlatChannelList()
    m.flatChannelList = []
    
    if m.allChannels = invalid then return
    
    for i = 0 to m.allChannels.getChildCount() - 1
        section = m.allChannels.getChild(i)
        if section = invalid then continue for
        
        if section.getChildCount() = 0 then
            m.flatChannelList.Push(section)
        else
            for j = 0 to section.getChildCount() - 1
                channel = section.getChild(j)
                if channel <> invalid then
                    m.flatChannelList.Push(channel)
                end if
            end for
        end if
    end for
    
    print "Total channels in flat list: "; m.flatChannelList.Count()
end sub

sub changeChannel(direction as Integer)
    print ">>> CHANGECHANNEL: Function called with direction parameter = "; direction
    print ">>> CHANGECHANNEL: flatChannelList.Count() = "; m.flatChannelList.Count()
    print ">>> CHANGECHANNEL: currentChannelIndex = "; m.currentChannelIndex
    
    if m.flatChannelList.Count() = 0 then 
        print ">>> CHANGECHANNEL ERROR: flatChannelList is empty!"
        return
    end if
    
    m.currentChannelIndex = m.currentChannelIndex + direction
    
    if m.currentChannelIndex < 0 then
        m.currentChannelIndex = m.flatChannelList.Count() - 1
    else if m.currentChannelIndex >= m.flatChannelList.Count() then
        m.currentChannelIndex = 0
    end if
    
    print ">>> CHANGECHANNEL: New index = "; m.currentChannelIndex
    
    channel = m.flatChannelList[m.currentChannelIndex]
    if channel <> invalid then
        print ">>> CHANGECHANNEL: Playing channel: "; channel.title
        showChannelInfo(channel)
        playChannel(channel)
    else
        print ">>> CHANGECHANNEL ERROR: No valid channel at index "; m.currentChannelIndex
    end if
end sub

sub showChannelInfo(channel as Object)
    if m.channelInfoOverlay = invalid or m.channelInfoLabel = invalid then return
    
    channelNumber = (m.currentChannelIndex + 1).ToStr()
    totalChannels = m.flatChannelList.Count().ToStr()
    m.channelInfoLabel.text = channelNumber + "/" + totalChannels + " - " + channel.title
    
    m.channelInfoOverlay.visible = true
    
    ' Create a timer to hide the overlay after 3 seconds
    if m.channelInfoTimer <> invalid then
        m.channelInfoTimer.control = "stop"
    end if
    
    m.channelInfoTimer = CreateObject("roSGNode", "Timer")
    m.channelInfoTimer.duration = 3
    m.channelInfoTimer.repeat = false
    m.channelInfoTimer.ObserveField("fire", "hideChannelInfo")
    m.channelInfoTimer.control = "start"
end sub

sub hideChannelInfo()
    if m.channelInfoOverlay <> invalid then
        m.channelInfoOverlay.visible = false
    end if
end sub

' ==================== Video settings menu ====================

sub showVideoOptionsMenu()
    print ">>> VIDEO OPTIONS: Showing options menu"
    
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "⚙️ Playback options"
    dialog.buttons = ["🔊 Audio Settings", "💬 Subtitles", "ℹ️ Channel Details", "❌ Close"]
    
    m.top.dialog = dialog
    m.top.dialog.observeField("buttonSelected", "onVideoOptionSelected")
end sub

sub onVideoOptionSelected()
    buttonIdx = m.top.dialog.buttonSelected
    
    m.top.dialog.unobserveField("buttonSelected")
    m.top.dialog.close = true
    
    if buttonIdx = 0 then
        ' Change audio track
        showAudioTracksMenu()
    else if buttonIdx = 1 then
        ' Subtitles
        showSubtitlesMenu()
    else if buttonIdx = 2 then
        ' Channel info
        showCurrentChannelInfo()
    end if
    
    m.top.setFocus(true)
end sub

sub showAudioTracksMenu()
    print ">>> AUDIO TRACKS: Fetching audio tracks"
    
    if m.video = invalid then return
    
    ' Get available audio track info and try multiple properties for compatibility
    audioTracks = m.video.audioTracks
    
    print ">>> AUDIO: audioTracks = "; audioTracks
    
    if audioTracks = invalid or audioTracks.Count() = 0 then
        ' Intentar con availableAudioTracks
        audioTracks = m.video.availableAudioTracks
        print ">>> AUDIO: availableAudioTracks = "; audioTracks
    end if
    
    ' Debug: Show stream information
    print ">>> AUDIO: streamInfo = "; m.video.streamInfo
    print ">>> AUDIO: audioFormat = "; m.video.audioFormat
    
    if audioTracks = invalid or audioTracks.Count() = 0 then
        ' how debug information
        message = "No alternate audio tracks detected." + chr(10) + chr(10)
        message = message + "Audio format: " + toStr(m.video.audioFormat) + chr(10)
        message = message + "Video status: " + m.video.state
        
        dialog = CreateObject("roSGNode", "Dialog")
        dialog.title = "🔊 Audio tracks"
        dialog.message = message
        dialog.buttons = ["OK"]
        m.top.dialog = dialog
        m.top.dialog.observeField("buttonSelected", "onSimpleDialogClosed")
        return
    end if
    
    ' Create list of audio tracks
    m.audioTracksList = []
    buttons = []
    
    ' Get current audio track
    currentTrackIndex = -1
    if m.video.currentAudioTrack <> invalid then
        currentTrackIndex = m.video.currentAudioTrack
    end if
    
    for i = 0 to audioTracks.Count() - 1
        track = audioTracks[i]
        trackName = ""
        
        print ">>> AUDIO TRACK "; i; ": "; track
        
        ' Generate track name using different properties
        language = ""
        if type(track) = "roAssociativeArray" then
            if track.Language <> invalid and track.Language <> "" then
                language = track.Language
            else if track.language <> invalid and track.language <> "" then
                language = track.language
            end if
            
            if language <> "" then
                trackName = getLanguageName(language)
            else
                trackName = "Track " + (i + 1).ToStr()
            end if
            
            ' Add name if available
            if track.Name <> invalid and track.Name <> "" then
                trackName = trackName + " (" + track.Name + ")"
            else if track.name <> invalid and track.name <> "" then
                trackName = trackName + " (" + track.name + ")"
            end if
        else if type(track) = "String" or type(track) = "roString" then
            trackName = getLanguageName(track)
        else
            trackName = "List " + (i + 1).ToStr()
        end if
        
        ' Highlight current track
        if i = currentTrackIndex then
            trackName = "✓ " + trackName
        end if
        
        buttons.Push(trackName)
        m.audioTracksList.Push(i)
    end for
    
    buttons.Push("❌ Cancel")
    
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "🔊 Select audio track (" + audioTracks.Count().ToStr() + " disponibles)"
    dialog.buttons = buttons
    
    m.top.dialog = dialog
    m.top.dialog.observeField("buttonSelected", "onAudioTrackSelected")
end sub

function toStr(value as Dynamic) as String
    if value = invalid then return "N/A"
    if type(value) = "String" or type(value) = "roString" then return value
    if type(value) = "Integer" or type(value) = "roInt" then return value.ToStr()
    if type(value) = "Float" or type(value) = "roFloat" then return Str(value)
    return type(value)
end function

sub onAudioTrackSelected()
    buttonIdx = m.top.dialog.buttonSelected
    
    m.top.dialog.unobserveField("buttonSelected")
    m.top.dialog.close = true
    
    if m.audioTracksList <> invalid and buttonIdx < m.audioTracksList.Count() then
        trackIndex = m.audioTracksList[buttonIdx]
        print ">>> AUDIO: Changing tracks "; trackIndex
        
        ' Try changing the audio track using different methods.
        ' Method 1: audioTrack (direct index)
        m.video.audioTrack = trackIndex
        
        ' Method 2: selectAudioTrack
        m.video.selectAudioTrack = trackIndex
        
        ' Show confirmation message
        showChannelInfoMessage("🔊 Audio: Track " + (trackIndex + 1).ToStr() + " selected")
    end if
    
    m.top.setFocus(true)
end sub

sub showSubtitlesMenu()
    print ">>> SUBTITLES: Fetching subtitles"
    
    if m.video = invalid then return
    
    ' Get available subtitle track information
    subtitleTracks = m.video.availableCaptionTracks
    
    buttons = ["❌ Subtitles off"]
    m.subtitleTracksList = [-1] ' -1 = desactivar
    
    if subtitleTracks <> invalid and subtitleTracks.Count() > 0 then
        for i = 0 to subtitleTracks.Count() - 1
            track = subtitleTracks[i]
            trackName = ""
            
            if track.Language <> invalid and track.Language <> "" then
                trackName = getLanguageName(track.Language)
            else
                trackName = "Subtitle " + (i + 1).ToStr()
            end if
            
            if track.Description <> invalid and track.Description <> "" then
                trackName = trackName + " (" + track.Description + ")"
            end if
            
            buttons.Push(trackName)
            m.subtitleTracksList.Push(i)
        end for
    end if
    
    buttons.Push("❌ Cancel")
    
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "💬 Subtitles"
    
    if subtitleTracks = invalid or subtitleTracks.Count() = 0 then
        dialog.message = "No subtitles available for this channel."
    end if
    
    dialog.buttons = buttons
    
    m.top.dialog = dialog
    m.top.dialog.observeField("buttonSelected", "onSubtitleTrackSelected")
end sub

sub onSubtitleTrackSelected()
    buttonIdx = m.top.dialog.buttonSelected
    
    m.top.dialog.unobserveField("buttonSelected")
    m.top.dialog.close = true
    
    if m.subtitleTracksList <> invalid and buttonIdx < m.subtitleTracksList.Count() then
        trackIndex = m.subtitleTracksList[buttonIdx]
        
        if trackIndex = -1 then
            print ">>> SUBTITLES: Disabling subtitles"
            m.video.suppressCaptions = true
            showChannelInfoMessage("💬 Subtitles off")
        else
            print ">>> SUBTITLES: Turning subtitles on "; trackIndex
            m.video.suppressCaptions = false
            m.video.selectCaptionTrack = trackIndex
            showChannelInfoMessage("💬 Subtitles on")
        end if
    end if
    
    m.top.setFocus(true)
end sub

sub showCurrentChannelInfo()
    if m.flatChannelList = invalid or m.flatChannelList.Count() = 0 then return
    if m.currentChannelIndex < 0 or m.currentChannelIndex >= m.flatChannelList.Count() then return
    
    channel = m.flatChannelList[m.currentChannelIndex]
    if channel = invalid then return
    
    message = "Channel: " + channel.title + chr(10)
    message = message + "Position: " + (m.currentChannelIndex + 1).ToStr() + " de " + m.flatChannelList.Count().ToStr() + chr(10)
    
    if m.video <> invalid then
        state = m.video.state
        message = message + "State: " + state + chr(10)
        
        ' Audio information
        audioTracks = m.video.availableAudioTracks
        if audioTracks <> invalid then
            message = message + "Audio tracks: " + audioTracks.Count().ToStr() + chr(10)
        end if
        
        ' Subtitle information
        captionTracks = m.video.availableCaptionTracks
        if captionTracks <> invalid then
            message = message + "Subtitles: " + captionTracks.Count().ToStr()
        end if
    end if
    
    dialog = CreateObject("roSGNode", "Dialog")
    dialog.title = "ℹ️ Channel information"
    dialog.message = message
    dialog.buttons = ["OK"]
    
    m.top.dialog = dialog
    m.top.dialog.observeField("buttonSelected", "onSimpleDialogClosed")
end sub

sub onSimpleDialogClosed()
    m.top.dialog.unobserveField("buttonSelected")
    m.top.dialog.close = true
    m.top.setFocus(true)
end sub

sub showChannelInfoMessage(message as String)
    if m.channelInfoOverlay = invalid or m.channelInfoLabel = invalid then return
    
    m.channelInfoLabel.text = message
    m.channelInfoOverlay.visible = true
    
    if m.channelInfoTimer <> invalid then
        m.channelInfoTimer.control = "stop"
    end if
    
    m.channelInfoTimer = CreateObject("roSGNode", "Timer")
    m.channelInfoTimer.duration = 2
    m.channelInfoTimer.repeat = false
    m.channelInfoTimer.ObserveField("fire", "hideChannelInfo")
    m.channelInfoTimer.control = "start"
end sub

function getLanguageName(code as String) as String
    languages = {
        "es": "Spanish",
        "spa": "Spanish",
        "spanish": "Spanish",
        "en": "English",
        "eng": "English",
        "english": "English",
        "pt": "Portugues",
        "por": "Portugues",
        "portuguese": "Portugues",
        "fr": "French",
        "fra": "French",
        "fre": "French",
        "french": "French",
        "de": "German",
        "deu": "German",
        "ger": "German",
        "german": "German",
        "it": "Italian",
        "ita": "Italian",
        "italian": "Italian",
        "ja": "Japanese",
        "jpn": "Japanese",
        "japanese": "Japanese",
        "ko": "Korean",
        "kor": "Korean",
        "korean": "Korean",
        "zh": "Chinese",
        "chi": "Chinese",
        "zho": "Chinese",
        "chinese": "Chinese",
        "ru": "Russian",
        "rus": "Russian",
        "russian": "Russian",
        "ar": "Arab",
        "ara": "Arab",
        "arabic": "Arab",
        "und": "Unknown",
        "mul": "Multipe"
    }
    
    lowerCode = LCase(code)
    if languages.DoesExist(lowerCode) then
        return languages[lowerCode]
    end if
    
    return code
end function

' ==================== Channel Preview ====================

sub onChannelFocused()
    ' Update channel preview on selection change
    if m.isPlayingVideo then return
    if m.channelList = invalid then return
    
    focusedIndex = m.channelList.itemFocused
    print ">>> PREVIEW: Channel focus = "; focusedIndex

    ' Retrieve the focused channel
    channel = getChannelByFocusIndex(focusedIndex)
    if channel <> invalid then
        m.lastFocusedChannel = focusedIndex
        playPreviewChannel(focusedIndex)
    end if
end sub

function getChannelByFocusIndex(focusIndex as Integer) as Object
    return getChannelFromListItem(m.channelList, focusIndex)
end function

function getChannelFromListItem(list as Object, itemIndex as Integer) as Object
    if list = invalid or list.content = invalid then return invalid

    content = list.content
    if content.getChildCount() = 0 then return invalid

    firstChild = content.getChild(0)
    if firstChild = invalid then return invalid

    if firstChild.getChildCount() = 0 then
        if itemIndex >= 0 and itemIndex < content.getChildCount() then
            return content.getChild(itemIndex)
        end if

        return invalid
    end if

    sectionIndex = 0
    if list.currFocusSection <> invalid then
        sectionIndex = list.currFocusSection
    end if

    if sectionIndex >= 0 and sectionIndex < content.getChildCount() then
        section = content.getChild(sectionIndex)
        sectionItemIndex = getSectionChildIndexForListItem(content, sectionIndex, itemIndex)

        if section <> invalid and sectionItemIndex >= 0 and sectionItemIndex < section.getChildCount() then
            return section.getChild(sectionItemIndex)
        end if
    end if

    return getChannelFromFlatListItem(content, itemIndex)
end function

function getSectionChildIndexForListItem(content as Object, sectionIndex as Integer, itemIndex as Integer) as Integer
    if content = invalid then return -1
    if sectionIndex < 0 or sectionIndex >= content.getChildCount() then return -1

    section = content.getChild(sectionIndex)
    if section = invalid then return -1

    sectionCount = section.getChildCount()
    if sectionCount = 0 then return -1

    previousChannelCount = 0
    if sectionIndex > 0 then
        for i = 0 to sectionIndex - 1
            previousSection = content.getChild(i)
            if previousSection <> invalid then
                previousChannelCount = previousChannelCount + previousSection.getChildCount()
            end if
        end for
    end if

    flatItemIndex = itemIndex - previousChannelCount
    if flatItemIndex >= 0 and flatItemIndex < sectionCount then
        return flatItemIndex
    end if

    if itemIndex >= 0 and itemIndex < sectionCount then
        return itemIndex
    end if

    return -1
end function

function getChannelFromFlatListItem(content as Object, itemIndex as Integer) as Object
    if content = invalid or itemIndex < 0 then return invalid

    channelIndex = 0
    for i = 0 to content.getChildCount() - 1
        section = content.getChild(i)
        if section = invalid then continue for

        if section.getChildCount() = 0 then
            if channelIndex = itemIndex then return section
            channelIndex = channelIndex + 1
        else
            sectionCount = section.getChildCount()
            if itemIndex < channelIndex + sectionCount then
                return section.getChild(itemIndex - channelIndex)
            end if
            channelIndex = channelIndex + sectionCount
        end if
    end for

    return invalid
end function

sub playPreviewChannel(channelIndex as Integer)
    if m.previewVideo = invalid then return
    if m.flatChannelList = invalid or m.flatChannelList.Count() = 0 then return
    
    channel = getChannelByFocusIndex(channelIndex)
    if channel = invalid and channelIndex >= 0 and channelIndex < m.flatChannelList.Count() then
        channel = m.flatChannelList[channelIndex]
    end if
    
    if channel = invalid or channel.url = invalid then 
        print ">>> PREVIEW: Failed to retrieve channel"
        return
    end if
    
    ' Skip preview reload if the channel is unchanged
    if m.previewVideo.content <> invalid and m.previewVideo.content.url = channel.url then
        return
    end if
    
    print ">>> PREVIEW: Starting preview playback: "; channel.title
    
    ' Update channel name
    if m.previewChannelName <> invalid then
        m.previewChannelName.text = channel.title
    end if
    
    ' Create preview content
    previewContent = CreateObject("roSGNode", "ContentNode")
    previewContent.url = channel.url
    previewContent.title = channel.title
    previewContent.streamFormat = "hls"
    previewContent.HttpSendClientCertificates = true
    previewContent.HttpCertificatesFile = "common:/certs/ca-bundle.crt"
    
    m.previewVideo.content = previewContent
    m.previewVideo.control = "play"
    m.previewVideo.mute = true ' Disable preview audio
end sub

sub stopPreviewVideo()
    if m.previewVideo <> invalid then
        m.previewVideo.control = "stop"
        m.previewVideo.visible = false
    end if
end sub

sub onChannelSelected()
    selectChannelFromList(m.channelList)
end sub

sub onOverlayChannelSelected()
    selectChannelFromList(m.channelOverlayList)
    m.channelOverlay.visible = false
    m.overlayVisible = false
end sub

sub selectChannelFromList(list as Object)
    print ">>> SELECTCHANNEL: Selecting channel from list"
    
    if list.content = invalid or list.content.getChildCount() = 0 then
        print ">>> SELECTCHANNEL ERROR: Invalid or empty channel list"
        return
    end if
    
    firstChild = list.content.getChild(0)
    if firstChild = invalid then 
        print ">>> SELECTCHANNEL ERROR: firstChild invalid"
        return
    end if
    
    content = getChannelFromListItem(list, list.itemSelected)
    print ">>> SELECTCHANNEL: section = "; list.currFocusSection; ", item = "; list.itemSelected
    
    if content = invalid then 
        print ">>> SELECTCHANNEL ERROR: Selected content is invalid"
        return
    end if
    
    print ">>> SELECTCHANNEL: Selecting channel: "; content.title
    print ">>> SELECTCHANNEL: URL: "; content.url
    
    findChannelIndexByUrl(content.url)
    
    print ">>> SELECTCHANNEL: currentChannelIndex set to = "; m.currentChannelIndex
    playChannel(content)
end sub

sub findChannelIndexByUrl(url as String)
    if m.flatChannelList = invalid or m.flatChannelList.Count() = 0 then
        print ">>> FINDINDEX ERROR: flatChannelList contains no channels"
        m.currentChannelIndex = 0
        return
    end if
    
    for i = 0 to m.flatChannelList.Count() - 1
        channel = m.flatChannelList[i]
        if channel <> invalid and channel.url = url then
            m.currentChannelIndex = i
            print ">>> FINDINDEX: Channel located in index "; i
            return
        end if
    end for
    
    print ">>> FINDINDEX: No channel found, falling back to index 0"
    m.currentChannelIndex = 0
end sub

sub reloadCurrentChannel()
    print ">>> RELOAD: Reloading current channel"
    
    if m.flatChannelList = invalid or m.currentChannelIndex < 0 then
        print ">>> RELOAD ERROR: There is no channel to reload."
        return
    end if
    
    channel = m.flatChannelList[m.currentChannelIndex]
    if channel = invalid then
        print ">>> RELOAD ERROR: Invalid channel"
        return
    end if
    
    ' Stop the current video.
    m.video.control = "stop"
    
    ' Create new content
    content = CreateObject("roSGNode", "ContentNode")
    content.title = channel.title
    content.url = channel.url
    content.streamFormat = "hls"
    
    print ">>> RELOAD: Reloading: "; channel.title
    
    ' Force the reload, skipping the check for the same channel
    m.video.content = invalid
    
    ' Small delay and then play
    content.HttpSendClientCertificates = true
    content.HttpCertificatesFile = "common:/certs/ca-bundle.crt"
    m.video.EnableCookies()
    m.video.SetCertificatesFile("common:/certs/ca-bundle.crt")
    m.video.InitClientCertificates()
    
    m.video.content = content
    m.video.control = "play"
    m.top.setFocus(true)
    
    print ">>> RELOAD: Channel reloaded successfully"
end sub

sub playChannel(content as Object)
	content.streamFormat = "hls, mp4, mkv, mp3, avi, m4v, ts, mpeg-4, flv, vob, ogg, ogv, webm, mov, wmv, asf, amv, mpg, mp2, mpeg, mpe, mpv, mpeg2"

	if m.video.content <> invalid and m.video.content.url = content.url then 
		print ">>> PLAY: MChannel unchanged, skipping reload"
		return
	end if

	print ">>> PLAY: Reloading channel: "; content.title

	' Stop preview playback
	if m.previewVideo <> invalid then
		m.previewVideo.control = "stop"
	end if

	content.HttpSendClientCertificates = true
	content.HttpCertificatesFile = "common:/certs/ca-bundle.crt"
	m.video.EnableCookies()
	m.video.SetCertificatesFile("common:/certs/ca-bundle.crt")
	m.video.InitClientCertificates()

	m.video.content = content

	m.top.backgroundURI = "pkg:/images/rsgde_bg_hd.jpg"
	m.video.trickplaybarvisibilityauto = false
	
	m.video.visible = true
	m.video.translation = [0, 0]
	m.video.width = 1920
	m.video.height = 1080
	
	m.channelList.visible = false
	m.sidePanel.visible = false
	m.previewContainer.visible = false
	
	if not m.overlayVisible then
		m.channelOverlay.visible = false
	end if
	
	m.isPlayingVideo = true
	
	m.video.control = "play"
	
	' Ensure Scene focus for keyboard event handling
	m.video.setFocus(false)
	m.channelList.setFocus(false)
	m.playlistList.setFocus(false)
	m.top.setFocus(true)
	
	' Save current state (last playlist and channel)
	saveLastState()
	
	print ">>> PLAY: Video iniciado, control = play"
	print ">>> PLAY: Scene is focused for keyboard input"
end sub

function isValidUrl(url as String) as Boolean
    if url = "" then return false
    
    httpReg = CreateObject("roRegex", "^https?://", "i")
    if not httpReg.isMatch(url) then return false
    
    urlReg = CreateObject("roRegex", "^https?://[^\s/$.?#].[^\s]*$", "i")
    return urlReg.isMatch(url)
end function

' ==================== Save/Restore previous state ====================

sub saveLastState()
    print ">>> SAVE STATE: Saving current state"
    
    reg = CreateObject("roRegistrySection", "lastState")
    
    ' Store current playlist index
    reg.Write("playlistIndex", m.currentPlaylist.ToStr())
    
    ' Save active channel URL
    if m.flatChannelList <> invalid and m.currentChannelIndex >= 0 and m.currentChannelIndex < m.flatChannelList.Count() then
        channel = m.flatChannelList[m.currentChannelIndex]
        if channel <> invalid and channel.url <> invalid then
            reg.Write("channelUrl", channel.url)
            reg.Write("channelTitle", channel.title)
            print ">>> SAVE STATE: Channel saved = "; channel.title
        end if
    end if
    
    ' Save channel index as backup”
    reg.Write("channelIndex", m.currentChannelIndex.ToStr())
    
    reg.Flush()
    print ">>> SAVE STATE: Successfully saved state"
end sub

function loadLastState() as Object
    print ">>> LOAD STATE: Loading saved state"
    
    state = {
        playlistIndex: 0,
        channelUrl: "",
        channelTitle: "",
        channelIndex: 0
    }
    
    reg = CreateObject("roRegistrySection", "lastState")
    
    if reg.Exists("playlistIndex") then
        state.playlistIndex = reg.Read("playlistIndex").ToInt()
        print ">>> LOAD STATE: playlistIndex = "; state.playlistIndex
    end if
    
    if reg.Exists("channelUrl") then
        state.channelUrl = reg.Read("channelUrl")
        print ">>> LOAD STATE: channelUrl = "; state.channelUrl
    end if
    
    if reg.Exists("channelTitle") then
        state.channelTitle = reg.Read("channelTitle")
        print ">>> LOAD STATE: channelTitle = "; state.channelTitle
    end if
    
    if reg.Exists("channelIndex") then
        state.channelIndex = reg.Read("channelIndex").ToInt()
        print ">>> LOAD STATE: channelIndex = "; state.channelIndex
    end if
    
    return state
end function

sub restorePendingChannel()
    ' Restore pending channel after loading the list
    if m.pendingChannelUrl = invalid or m.pendingChannelUrl = "" then return
    
    print ">>> RESTORE: Finding pending channel: "; m.pendingChannelUrl
    
    ' Retrieve channel using URL
    for i = 0 to m.flatChannelList.Count() - 1
        channel = m.flatChannelList[i]
        if channel <> invalid and channel.url = m.pendingChannelUrl then
            m.currentChannelIndex = i
            m.lastFocusedChannel = i
            
            ' Go to channel in list
            if m.channelList <> invalid then
                m.channelList.jumpToItem = i
            end if
            
            ' Start channel preview
            playPreviewChannel(i)
            
            print ">>> RESTORE: Channel found and selected in index "; i
            m.pendingChannelUrl = invalid
            return
        end if
    end for
    
    print ">>> RESTORE: No channel found, defaulting to first channel"
    m.pendingChannelUrl = invalid
end sub
