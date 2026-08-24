import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Ui
import qs.Commons

Panel {
  id: root
  moduleName: "io.github.tyrichards.clarity"
  ipcTarget: "clarity"

  property bool statusLoaded: false
  property bool installed: false
  property bool clarityActive: false
  property int optimisticClarityState: -1
  property bool manualEnabled: true
  property bool scheduleEnabled: false
  property bool scheduleDraftOpen: false
  property var scheduleWindows: []
  property string pendingScheduleStart: ""
  property string pendingScheduleEnd: ""
  property int pendingScheduleIndex: -1
  property bool permanentEnabled: false
  property bool adultEnableArmed: false
  property int permanentCount: 0
  property int distractionCount: 0
  property int aiAllowCount: 0
  property int whitelistCount: 0
  property var whitelistSites: []
  property var categoryCounts: ({})
  property bool whitelistExpanded: false
  property bool whitelistListExpanded: false
  property string pendingWhitelistSite: ""
  property string adultUpdated: ""
  property string reason: "Setup required"
  property string statusMessage: ""
  property string scheduleError: ""
  property string pendingAction: ""
  property string pendingSecret: ""
  property bool unlockChecking: false
  property real unlockProgress: 0.0
  property bool cursorActive: false
  property string focusSection: "header"
  property int taglineIndex: -1
  readonly property var focusTaglines: [
    "Fighting the feeds...",
    "Shooing distractions...",
    "Blocking the nonsense...",
    "Quieting the internet...",
    "Taming the algorithm...",
    "Hiding shiny things...",
    "Boarding rabbit holes...",
    "Disarming the feeds...",
    "Muting the nonsense...",
    "Dodging dopamine...",
    "Guarding your focus...",
    "Protecting your brain...",
    "Clearing brainspace...",
    "Reclaiming attention...",
    "Finding your focus...",
    "Focusing in now...",
    "Entering focus mode...",
    "Getting serious now...",
    "Doing the one thing...",
    "Back to the thing...",
    "Making room to think...",
    "Shushing the internet...",
    "Internet, behave...",
    "Nice try, internet...",
    "Not today, algorithm.",
    "Begone, distractions.",
    "No scrolling for you.",
    "Reddit can wait.",
    "The feed can wait.",
    "Stay on target...",
    "Locking in...",
    "Brain online...",
    "Focus engaged...",
    "Nonsense disabled.",
    "Rabbit holes closed.",
    "Dopamine denied.",
    "Distraction denied.",
    "Doing focus things...",
    "Making brain go brrr...",
    "Deploying focus...",
    "Engaging big brain..."
  ]

  readonly property var blockedSiteCategories: [
    { "label": "SOCIAL & FEEDS", "key": "Social & Feeds" },
    { "label": "TORRENTS", "key": "Torrents" },
    { "label": "VIDEO & STREAMING", "key": "Video & Streaming" },
    { "label": "GAMBLING", "key": "Gambling" },
    { "label": "SHOPPING", "key": "Shopping" },
    { "label": "ADULT", "key": "Adult" }
  ]
  readonly property color protectedAccordionBackground: Qt.rgba(Math.min(1, Color.background.r * 1.45), Math.min(1, Color.background.g * 1.45), Math.min(1, Color.background.b * 1.45), Color.background.a)
  readonly property bool effectiveClarityActive: root.optimisticClarityState >= 0
    ? root.optimisticClarityState === 1
    : root.clarityActive
  readonly property bool busy: actionProc.running || root.unlockChecking || !root.statusLoaded
  readonly property bool passwordIncorrect: root.statusMessage.toLowerCase().indexOf("password incorrect") >= 0
  readonly property bool scheduleEditorOpen: root.scheduleEnabled || root.scheduleDraftOpen
  readonly property bool scheduleEditing: root.pendingScheduleIndex >= 0 && root.pendingAction !== "schedule-remove"
  readonly property bool passwordPromptVisible: root.pendingAction !== ""
  readonly property string cli: localPath(Qt.resolvedUrl("bin/clarityctl"))
  readonly property string setupLauncher: localPath(Qt.resolvedUrl("bin/clarity-setup"))
  readonly property string icon: "󰈈"
  readonly property string heroTitle: !root.statusLoaded ? "Clarity" : root.installed ? "Clarity" : "Clarity Setup"
  readonly property string heroMeta: {
    if (!root.statusLoaded) return "LOADING…"
    if (!root.installed) return "ACTIVATE TO BEGIN"
    if (!root.effectiveClarityActive) return "DISTRACTION BLOCK OFF"
    return root.focusTaglines[Math.max(0, root.taglineIndex)].toUpperCase()
  }

  component SpacedRule: Item {
    width: parent ? parent.width : 0
    height: 31

    PanelSeparator {
      anchors.left: parent.left
      anchors.right: parent.right
      y: 15
      foreground: root.bar.foreground
    }
  }

  function advanceTagline() {
    taglineIndex = (taglineIndex + 1) % focusTaglines.length
  }

  function localPath(url) {
    var value = url.toString()
    return value.indexOf("file://") === 0 ? decodeURIComponent(value.substring(7)) : value
  }

  function compactNumber(value) {
    if (value >= 1000000) return (value / 1000000).toFixed(1) + "m"
    if (value >= 1000) return (value / 1000).toFixed(value >= 10000 ? 0 : 1) + "k"
    return String(value)
  }

  function categoryCount(key) {
    var value = root.categoryCounts && root.categoryCounts[key] !== undefined
      ? Number(root.categoryCounts[key])
      : key === "Adult" ? root.permanentCount : 0
    return value.toLocaleString(Qt.locale("en_US"), "f", 0)
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function updateState(raw) {
    try {
      var state = JSON.parse(String(raw || "{}"))
      installed = state.installed === true
      clarityActive = state.active === true
      if (!actionProc.running && (optimisticClarityState < 0 || clarityActive === (optimisticClarityState === 1)))
        optimisticClarityState = -1
      statusLoaded = true
      manualEnabled = state.manualEnabled !== false
      scheduleEnabled = state.scheduleEnabled === true
      if (scheduleEnabled) scheduleDraftOpen = false
      var windows = state.scheduleWindows
      if (!Array.isArray(windows)) {
        windows = [{
          "start": String(state.scheduleStart || "09:00"),
          "end": String(state.scheduleEnd || "17:00")
        }]
      }
      scheduleWindows = windows
      permanentEnabled = state.permanentEnabled === true
      permanentCount = Number(state.permanentCount || 0)
      distractionCount = Number(state.distractionCount || 0)
      aiAllowCount = Number(state.aiAllowCount || 0)
      whitelistCount = Number(state.whitelistCount || 0)
      whitelistSites = Array.isArray(state.whitelistSites) ? state.whitelistSites : []
      if (whitelistSites.length === 0) whitelistListExpanded = false
      categoryCounts = state.categoryCounts || ({})
      adultUpdated = String(state.adultUpdated || "")
      reason = String(state.reason || "")
    } catch (error) {
      statusLoaded = true
      installed = false
      clarityActive = false
      scheduleEnabled = false
      reason = "Setup required"
    }
  }

  function requestPassword(action) {
    pendingAction = action
    passwordField.text = ""
    statusMessage = ""
    Qt.callLater(function() { passwordField.forceActiveFocus() })
  }

  function cancelPassword() {
    if (unlockChecking) return
    var cancelledAction = pendingAction
    pendingAction = ""
    pendingSecret = ""
    pendingScheduleStart = ""
    pendingScheduleEnd = ""
    pendingScheduleIndex = -1
    pendingWhitelistSite = ""
    passwordField.text = ""
    if (cancelledAction === "schedule-edit") {
      startField.text = ""
      endField.text = ""
    }
    Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
  }

  function runAction(args) {
    if (busy) return
    actionProc.command = [root.cli].concat(args)
    actionProc.running = true
  }

  function runProtected(args, secret) {
    if (busy) return
    pendingSecret = secret
    unlockProgress = 0.0
    unlockChecking = true
    unlockProgressAnimation.restart()
    actionProc.command = [root.cli].concat(args).concat(["--password-stdin"])
    actionProc.running = true
  }

  function completeAction(exitCode, stdoutText, stderrText) {
    var completedAction = root.pendingAction
    var output = String(exitCode === 0 ? stdoutText : stderrText).trim()
    unlockProgressAnimation.stop()
    root.unlockProgress = 1.0
    root.unlockChecking = false
    if (exitCode !== 0) root.optimisticClarityState = -1
    else if (completedAction === "disable") root.optimisticClarityState = 0
    var cleanedOutput = output.replace(/^clarity:\s*/, "")
    var passwordIncorrectOutput = exitCode !== 0 && output.toLowerCase().indexOf("incorrect clarity password") >= 0
    if (passwordIncorrectOutput) {
      root.statusMessage = "Clarity Password Incorrect."
    } else if (exitCode !== 0 && completedAction.indexOf("schedule-") === 0) {
      root.scheduleError = cleanedOutput
      root.statusMessage = ""
    } else {
      root.statusMessage = cleanedOutput
    }
    if (exitCode === 0 && completedAction.indexOf("schedule-") === 0)
      root.scheduleError = ""
    root.pendingSecret = ""
    root.refresh()
    if (exitCode === 0) {
      passwordField.text = ""
      if (completedAction === "schedule-add" || completedAction === "schedule-edit") {
        startField.text = ""
        endField.text = ""
      }
      root.pendingAction = ""
      root.pendingScheduleStart = ""
      root.pendingScheduleEnd = ""
      root.pendingScheduleIndex = -1
      if (completedAction === "whitelist-add") whitelistField.text = ""
      root.pendingWhitelistSite = ""
      Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
    } else {
      Qt.callLater(function() {
        passwordField.forceActiveFocus()
        passwordField.selectAll()
      })
    }
  }

  function toggleClarity() {
    if (busy || !statusLoaded) return
    if (!installed) {
      launchInstaller()
      return
    }
    if (clarityActive) requestPassword("disable")
    else if (scheduleEnabled) statusMessage = "The daily schedule controls Clarity right now."
    else {
      optimisticClarityState = 1
      runAction(["on"])
    }
  }

  function toggleSchedule() {
    if (!installed || busy) return
    if (!scheduleEnabled && scheduleWindows.length === 0) {
      scheduleDraftOpen = !scheduleDraftOpen
      return
    }
    requestPassword(scheduleEnabled ? "schedule-disable" : "schedule-enable")
  }

  function standardTime(value) {
    var parts = String(value || "").split(":")
    if (parts.length !== 2) return String(value || "")
    var hour = Number(parts[0])
    var minute = parts[1]
    var suffix = hour >= 12 ? "PM" : "AM"
    var displayHour = hour % 12
    if (displayHour === 0) displayHour = 12
    return displayHour + ":" + minute + " " + suffix
  }

  function militaryTime(value) {
    var raw = String(value || "").trim().toUpperCase().replace(/\./g, "")
    var standard = raw.match(/^(1[0-2]|0?[1-9])(?::?([0-5][0-9]))?\s*([AP]M)$/)
    if (standard) {
      var standardHour = Number(standard[1]) % 12
      if (standard[3] === "PM") standardHour += 12
      var standardMinute = standard[2] || "00"
      return (standardHour < 10 ? "0" : "") + standardHour + ":" + standardMinute
    }
    var clock = raw.match(/^([01]?\d|2[0-3])(?::([0-5][0-9]))?$/)
    if (clock) {
      var clockHour = Number(clock[1])
      var clockMinute = clock[2] || "00"
      return (clockHour < 10 ? "0" : "") + clockHour + ":" + clockMinute
    }
    if (/^\d{3,4}$/.test(raw)) {
      var compactHour = Number(raw.substring(0, raw.length - 2))
      var compactMinute = raw.substring(raw.length - 2)
      if (compactHour <= 23 && Number(compactMinute) <= 59)
        return (compactHour < 10 ? "0" : "") + compactHour + ":" + compactMinute
    }
    return ""
  }

  function normalizeTimeField(field) {
    var value = militaryTime(field.text)
    if (value !== "") field.text = standardTime(value)
    return value
  }

  function addScheduleWindow() {
    if (!installed || busy || !scheduleEditorOpen) return
    if (pendingScheduleIndex < 0 && scheduleWindows.length >= 3) {
      scheduleError = "Clarity supports up to three schedule windows."
      return
    }
    var start = normalizeTimeField(startField)
    var end = normalizeTimeField(endField)
    if (start === "" || end === "") {
      scheduleError = "Enter a valid start and end time."
      return
    }
    scheduleError = ""
    pendingScheduleStart = start
    pendingScheduleEnd = end
    requestPassword(pendingScheduleIndex >= 0 ? "schedule-edit" : "schedule-add")
  }

  function editScheduleWindow(index) {
    if (!installed || busy || index < 0 || index >= scheduleWindows.length) return
    pendingScheduleIndex = index
    startField.text = standardTime(scheduleWindows[index].start)
    endField.text = standardTime(scheduleWindows[index].end)
    statusMessage = ""
    scheduleError = ""
    Qt.callLater(function() { startField.forceActiveFocus(); startField.selectAll() })
  }

  function removeScheduleWindow(index) {
    if (!installed || busy || !scheduleEnabled) return
    pendingScheduleIndex = index
    requestPassword("schedule-remove")
  }

  function submitPassword() {
    if (passwordField.text === "" || busy) return
    var secret = passwordField.text
    if (pendingAction === "disable") {
      runProtected(["off"], secret)
    } else if (pendingAction === "schedule-enable") {
      runProtected(["schedule", "enabled"], secret)
    } else if (pendingAction === "schedule-disable") {
      runProtected(["schedule", "disabled"], secret)
    } else if (pendingAction === "schedule-add") {
      runProtected(["schedule", "add", pendingScheduleStart, pendingScheduleEnd], secret)
    } else if (pendingAction === "schedule-edit") {
      runProtected(["schedule", "edit", String(pendingScheduleIndex), pendingScheduleStart, pendingScheduleEnd], secret)
    } else if (pendingAction === "schedule-remove") {
      runProtected(["schedule", "remove", String(pendingScheduleIndex)], secret)
    } else if (pendingAction === "whitelist-add") {
      runProtected(["whitelist", "add", pendingWhitelistSite], secret)
    } else if (pendingAction === "whitelist-remove") {
      runProtected(["whitelist", "remove", pendingWhitelistSite], secret)
    }
  }

  function launchInstaller() {
    root.close()
    Quickshell.execDetached([root.setupLauncher])
  }

  function toggleWhitelistEntry() {
    if (!installed || busy) return
    whitelistExpanded = !whitelistExpanded
    if (whitelistExpanded) Qt.callLater(function() { whitelistField.forceActiveFocus() })
  }

  function toggleWhitelistList() {
    if (!installed || busy || whitelistSites.length === 0) return
    whitelistListExpanded = !whitelistListExpanded
  }

  function removeWhitelistSite(site) {
    if (!installed || busy) return
    pendingWhitelistSite = site
    requestPassword("whitelist-remove")
  }

  function addWhitelistSite() {
    if (!installed || busy) return
    var site = whitelistField.text.trim()
    if (site === "") {
      statusMessage = "Paste a website URL or domain to whitelist."
      return
    }
    pendingWhitelistSite = site
    requestPassword("whitelist-add")
  }

  function enablePermanentAdult() {
    if (!installed || permanentEnabled || busy) return
    if (!adultEnableArmed) {
      adultEnableArmed = true
      adultEnableConfirmTimer.restart()
      return
    }
    adultEnableConfirmTimer.stop()
    adultEnableArmed = false
    runAction(["enable-adult"])
  }

  function close() {
    if (unlockChecking) return
    root.controller.hide()
    cancelPassword()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  onOpenedChanged: {
    if (opened) {
      advanceTagline()
      refresh()
      cursorActive = false
      focusSection = "header"
    } else {
      adultEnableArmed = false
      scheduleDraftOpen = false
      whitelistListExpanded = false
      cancelPassword()
    }
  }

  Timer {
    id: adultEnableConfirmTimer
    interval: 6000
    onTriggered: root.adultEnableArmed = false
  }

  Timer {
    interval: 3000
    repeat: true
    running: root.opened
    onTriggered: root.refresh()
  }

  Process {
    id: statusProc
    command: [root.cli, "status"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateState(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        root.statusLoaded = true
        root.installed = false
        root.clarityActive = false
        root.scheduleEnabled = false
        root.reason = "Setup required"
      }
    }
  }

  Process {
    id: actionProc
    stdinEnabled: true
    stdout: StdioCollector { id: actionStdout; waitForEnd: true }
    stderr: StdioCollector { id: actionStderr; waitForEnd: true }
    onStarted: {
      if (root.pendingSecret !== "") {
        write(root.pendingSecret + "\n")
        root.pendingSecret = ""
      }
    }
    onExited: function(exitCode) {
      root.completeAction(exitCode, actionStdout.text, actionStderr.text)
    }
  }

  NumberAnimation {
    id: unlockProgressAnimation
    target: root
    property: "unlockProgress"
    from: 0.0
    to: 0.92
    duration: 4500
    easing.type: Easing.Linear
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.icon
    opacity: root.installed && !root.clarityActive ? 0.65 : 1.0
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(panelColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: root.pendingAction !== ""
      onMoveRequested: function(dx, dy) {
        if (!root.cursorActive) { root.cursorActive = true; return }
        if (dy > 0) root.focusSection = root.focusSection === "header" ? "schedule" : "whitelist"
        else if (dy < 0) root.focusSection = root.focusSection === "whitelist" ? "schedule" : "header"
      }
      onActivateRequested: {
        if (!root.cursorActive) return
        if (root.focusSection === "header") root.toggleClarity()
        else if (root.focusSection === "schedule") root.toggleSchedule()
        else root.toggleWhitelistEntry()
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: panelColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 0

        // Bluetooth-style hero: icon · title/status · primary switch.
        Item {
          width: parent.width
          implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight, claritySwitch.implicitHeight)

          Text {
            id: heroIcon
            text: root.icon
            color: root.bar.foreground
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            opacity: root.installed ? 1.0 : 0.5
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          SnappyToggleSwitch {
            id: claritySwitch
            visible: true
            checked: root.installed ? root.effectiveClarityActive : false
            busy: root.busy
            hasCursor: root.cursorActive && root.focusSection === "header"
            foreground: root.bar.foreground
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            onHovered: function(on) {
              if (!on) return
              root.cursorActive = true
              root.focusSection = "header"
            }
            onToggled: root.toggleClarity()
          }

          Text {
            id: clarityStatusIcon
            text: ""
            color: root.effectiveClarityActive ? "#00E436" : "#FF0040"
            opacity: 1.0
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.display
            anchors.right: claritySwitch.left
            anchors.rightMargin: Style.space(14)
            anchors.verticalCenter: claritySwitch.verticalCenter
            transformOrigin: Item.Center
          }

          SequentialAnimation {
            id: clarityStatusPulse
            running: root.effectiveClarityActive
            loops: Animation.Infinite

            NumberAnimation {
              target: clarityStatusIcon
              property: "opacity"
              from: 1.0
              to: 0.3
              duration: 756
              easing.type: Easing.InOutSine
            }
            NumberAnimation {
              target: clarityStatusIcon
              property: "opacity"
              from: 0.3
              to: 1.0
              duration: 756
              easing.type: Easing.InOutSine
            }

            onRunningChanged: if (!running) clarityStatusIcon.opacity = 1.0
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: claritySwitch.visible
              ? claritySwitch.width + clarityStatusIcon.implicitWidth + Style.space(26)
              : 0
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              width: parent.width
              text: root.heroTitle
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.heroMeta
              color: Qt.darker(root.bar.foreground, 1.4)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
              font.bold: true
              font.letterSpacing: 1.2
              elide: Text.ElideRight
            }
          }
        }

        Button {
          visible: root.statusLoaded && !root.installed
          width: parent.width
          text: "ACTIVATE"
          iconText: "󰐥"
          bordered: true
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: root.launchInstaller()
        }

        Column {
          visible: root.statusLoaded
          enabled: root.installed
          opacity: root.installed ? 1.0 : 0.35
          width: parent.width
          spacing: 0

          Column {
            id: protectedActionAccordions
            width: parent.width
            spacing: 0

            SpacedRule {}

          Item {
            id: passwordAccordion
            x: -panel.padding
            width: parent.width + panel.padding * 2
            height: root.passwordPromptVisible ? passwordContent.implicitHeight + 15 : 0
            clip: true

            Behavior on height {
              NumberAnimation {
                duration: root.passwordPromptVisible ? 180 : 70
                easing.type: Easing.OutCubic
              }
            }

            Rectangle {
              id: passwordAccordionBackground
              anchors.fill: parent
              color: root.protectedAccordionBackground
            }

            Rectangle {
              id: unlockProgressTrack
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.top: parent.top
              height: Style.space(5)
              opacity: root.unlockChecking ? 1.0 : 0.0
              color: Qt.rgba(Color.accent.r, Color.accent.g, Color.accent.b, 0.18)
              z: 2

              Rectangle {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                width: parent.width * root.unlockProgress
                color: Color.accent
              }
            }

            Column {
              id: passwordContent
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: panel.padding
              anchors.rightMargin: panel.padding
              spacing: Style.space(8)

              Item { width: parent.width; height: Style.space(5) }

              Item {
                width: parent.width
                implicitHeight: Math.max(passwordTitle.implicitHeight, passwordError.implicitHeight)

                PanelSectionHeader {
                  id: passwordTitle
                  text: "CLARITY PASSWORD"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                  id: passwordError
                  visible: root.passwordIncorrect
                  text: "password incorrect"
                  color: root.bar.urgent
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  horizontalAlignment: Text.AlignRight
                  anchors.right: parent.right
                  anchors.verticalCenter: parent.verticalCenter
                }
              }

              RowLayout {
                width: parent.width
                spacing: Style.space(8)
                enabled: !root.unlockChecking

                TextField {
                  id: passwordField
                  Layout.fillWidth: true
                  password: true
                  placeholderText: "Not your Linux password"
                  foreground: root.bar.foreground
                  background: BorderSurface {
                    color: Color.popups.background
                    borderSpec: passwordField._borderSpec
                    radius: Style.cornerRadius
                  }
                  onAccepted: root.submitPassword()
                  Keys.onEscapePressed: root.cancelPassword()
                }

                Button {
                  text: "CANCEL"
                  bordered: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  onClicked: root.cancelPassword()
                }

                Button {
                  text: "UNLOCK"
                  bordered: true
                  active: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  onClicked: root.submitPassword()
                }
              }
            }
          }
          }

          Column {
            id: blockedSitesSection
            width: parent.width
            spacing: Style.space(6)

            PanelSectionHeader {
              text: "SITES BLOCKED"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
            }

            GridLayout {
              width: parent.width
              columns: 2
              columnSpacing: Style.space(16)
              rowSpacing: Style.space(4)

              Repeater {
                model: root.blockedSiteCategories

                Text {
                  required property var modelData
                  Layout.fillWidth: true
                  text: "- " + modelData.label + ": " + root.categoryCount(modelData.key)
                  color: Qt.darker(root.bar.foreground, 1.25)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                  elide: Text.ElideRight
                }
              }
            }
          }

          SpacedRule {}

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(scheduleHeader.implicitHeight, scheduleSwitch.implicitHeight)

              PanelSectionHeader {
                id: scheduleHeader
                text: "SCHEDULE"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              ToggleSwitch {
                id: scheduleSwitch
                checked: root.scheduleEditorOpen
                busy: root.busy
                hasCursor: root.cursorActive && root.focusSection === "schedule"
                foreground: root.bar.foreground
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onHovered: function(on) {
                  if (!on) return
                  root.cursorActive = true
                  root.focusSection = "schedule"
                }
                onToggled: root.toggleSchedule()
              }
            }

            Column {
              id: scheduleControls
              visible: root.scheduleEditorOpen
              width: parent.width
              spacing: Style.space(8)

              ListView {
                id: scheduleWindowsList
                visible: count > 0
                width: parent.width
                height: Math.min(contentHeight, Style.space(132))
                model: root.scheduleWindows
                spacing: Style.space(4)
                clip: true

                ScrollBar.vertical: ScrollBar {}

                delegate: CursorSurface {
                  id: scheduleRow
                  required property var modelData
                  required property int index
                  width: scheduleWindowsList.width
                  height: scheduleRowBody.implicitHeight
                  foreground: root.bar.foreground
                  fill: Style.hoverFillFor(root.bar.foreground, Color.accent)

                  Item {
                    id: scheduleRowBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    implicitHeight: Math.max(scheduleCalendarIcon.implicitHeight, scheduleTimeLabel.implicitHeight, scheduleActions.implicitHeight) + Style.spacing.rowPaddingX

                    Text {
                      id: scheduleCalendarIcon
                      text: "󰃭"
                      color: Qt.darker(root.bar.foreground, 1.5)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.title
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      id: scheduleTimeLabel
                      text: root.standardTime(scheduleRow.modelData.start) + " – " + root.standardTime(scheduleRow.modelData.end)
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.body
                      anchors.left: scheduleCalendarIcon.right
                      anchors.leftMargin: Style.space(10)
                      anchors.right: scheduleActions.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      elide: Text.ElideRight
                    }

                    Row {
                      id: scheduleActions
                      spacing: Style.space(4)
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter

                      Item {
                        width: Style.space(22)
                        implicitHeight: scheduleEditIcon.implicitHeight

                        Text {
                          id: scheduleEditIcon
                          width: parent.width
                          text: "󰏫"
                          color: scheduleEditMouse.containsMouse ? root.bar.foreground : Qt.darker(root.bar.foreground, 1.4)
                          font.family: root.bar.fontFamily
                          font.pixelSize: Style.font.subtitle
                          horizontalAlignment: Text.AlignHCenter
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        MouseArea {
                          id: scheduleEditMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          enabled: !root.busy
                          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                          onClicked: root.editScheduleWindow(scheduleRow.index)
                        }

                        PanelToolTip {
                          visible: scheduleEditMouse.containsMouse
                          text: "Edit schedule"
                          fontFamily: root.bar.fontFamily
                        }
                      }

                      Item {
                        width: Style.space(22)
                        implicitHeight: scheduleDeleteIcon.implicitHeight

                        Text {
                          id: scheduleDeleteIcon
                          width: parent.width
                          text: "󰆴"
                          color: scheduleDeleteMouse.containsMouse ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
                          font.family: root.bar.fontFamily
                          font.pixelSize: Style.font.subtitle
                          horizontalAlignment: Text.AlignHCenter
                          anchors.verticalCenter: parent.verticalCenter
                        }

                        MouseArea {
                          id: scheduleDeleteMouse
                          anchors.fill: parent
                          hoverEnabled: true
                          enabled: !root.busy
                          cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                          onClicked: root.removeScheduleWindow(scheduleRow.index)
                        }

                        PanelToolTip {
                          visible: scheduleDeleteMouse.containsMouse
                          text: "Remove schedule"
                          fontFamily: root.bar.fontFamily
                        }
                      }
                    }
                  }
                }
              }

              RowLayout {
                width: parent.width
                spacing: Style.space(8)

                TextField {
                  id: startField
                  Layout.fillWidth: true
                  placeholderText: "9:00 AM"
                  horizontalAlignment: TextInput.AlignHCenter
                  foreground: root.bar.foreground
                  onEditingFinished: root.normalizeTimeField(startField)
                  onAccepted: endField.forceActiveFocus()
                }

                Text {
                  text: "to"
                  color: Qt.darker(root.bar.foreground, 1.4)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.bodySmall
                }

                TextField {
                  id: endField
                  Layout.fillWidth: true
                  placeholderText: "5:00 PM"
                  horizontalAlignment: TextInput.AlignHCenter
                  foreground: root.bar.foreground
                  onEditingFinished: root.normalizeTimeField(endField)
                  onAccepted: root.addScheduleWindow()
                }

                Button {
                  text: root.scheduleEditing ? "Save" : "Add"
                  iconText: root.scheduleEditing ? "󰏫" : "󰐕"
                  bordered: true
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                  fontSize: Style.font.bodySmall
                  onClicked: root.addScheduleWindow()
                }
              }

              Text {
                width: parent.width
                text: "Clarity blocker is ON within this window of time. Overnight schedules are supported."
                wrapMode: Text.WordWrap
                color: Qt.darker(root.bar.foreground, 1.55)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }

              Text {
                visible: root.scheduleError !== ""
                width: parent.width
                text: root.scheduleError
                wrapMode: Text.WordWrap
                color: "#FF0040"
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }

          SpacedRule {}

          Column {
            width: parent.width
            spacing: Style.space(16)

            Item {
              width: parent.width
              implicitHeight: Math.max(whitelistLabels.implicitHeight, whitelistButton.implicitHeight)

              Column {
                id: whitelistLabels
                anchors.left: parent.left
                anchors.right: whitelistButton.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(4)

                PanelSectionHeader {
                  text: "WHITELIST SITES"
                  foreground: root.bar.foreground
                  fontFamily: root.bar.fontFamily
                }
                Text {
                  width: parent.width
                  text: !root.installed
                    ? "Allow selected sites through focus blocking"
                    : root.whitelistCount === 0
                      ? "No sites allowed through yet"
                      : root.whitelistCount + (root.whitelistCount === 1 ? " site" : " sites")
                        + " bypass focus blocking"
                  color: Qt.darker(root.bar.foreground, 1.5)
                  font.family: root.bar.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              Button {
                id: whitelistButton
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.whitelistExpanded ? "Close" : "Whitelist"
                iconText: "󰘽"
                bordered: true
                hasCursor: root.cursorActive && root.focusSection === "whitelist"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.bodySmall
                onHovered: function(on) {
                  if (!on) return
                  root.cursorActive = true
                  root.focusSection = "whitelist"
                }
                onClicked: root.toggleWhitelistEntry()
              }
            }

            Button {
              visible: root.whitelistSites.length > 0
              width: parent.width
              text: "View all"
              iconText: ""
              bordered: true
              active: root.whitelistListExpanded
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.bodySmall
              onClicked: root.toggleWhitelistList()
            }

            Item {
              id: whitelistAccordion
              width: parent.width
              height: root.whitelistListExpanded ? Math.min(whitelistSitesList.contentHeight, Style.space(132)) : 0
              clip: true

              Behavior on height {
                NumberAnimation {
                  duration: root.whitelistListExpanded ? 180 : 70
                  easing.type: Easing.OutCubic
                }
              }

              ListView {
                id: whitelistSitesList
                anchors.fill: parent
                model: root.whitelistSites
                spacing: Style.space(4)
                clip: true

                delegate: CursorSurface {
                  id: whitelistRow
                  required property var modelData
                  required property int index
                  width: whitelistSitesList.width
                  height: whitelistRowBody.implicitHeight
                  hasCursor: whitelistRowMouse.containsMouse
                  foreground: root.bar.foreground
                  fill: Style.hoverFillFor(root.bar.foreground, Color.accent)

                  MouseArea {
                    id: whitelistRowMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !root.busy
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: root.removeWhitelistSite(String(whitelistRow.modelData))
                  }

                  Item {
                    id: whitelistRowBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.leftMargin: Style.space(10)
                    anchors.rightMargin: Style.space(10)
                    implicitHeight: Math.max(whitelistCheckIcon.implicitHeight, whitelistSiteLabel.implicitHeight, whitelistDeleteAction.implicitHeight) + Style.spacing.rowPaddingX

                    Text {
                      id: whitelistCheckIcon
                      text: ""
                      color: Qt.darker(root.bar.foreground, 1.5)
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.title
                      anchors.left: parent.left
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                      id: whitelistSiteLabel
                      text: String(whitelistRow.modelData)
                      color: root.bar.foreground
                      font.family: root.bar.fontFamily
                      font.pixelSize: Style.font.body
                      anchors.left: whitelistCheckIcon.right
                      anchors.leftMargin: Style.space(10)
                      anchors.right: whitelistDeleteAction.left
                      anchors.rightMargin: Style.space(8)
                      anchors.verticalCenter: parent.verticalCenter
                      elide: Text.ElideRight
                    }

                    Item {
                      id: whitelistDeleteAction
                      width: Style.space(22)
                      implicitHeight: whitelistDeleteIcon.implicitHeight
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter

                      Text {
                        id: whitelistDeleteIcon
                        width: parent.width
                        text: "󰆴"
                        color: whitelistDeleteMouse.containsMouse ? root.bar.urgent : Qt.darker(root.bar.foreground, 1.4)
                        font.family: root.bar.fontFamily
                        font.pixelSize: Style.font.subtitle
                        horizontalAlignment: Text.AlignHCenter
                        anchors.verticalCenter: parent.verticalCenter
                      }

                      MouseArea {
                        id: whitelistDeleteMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !root.busy
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: root.removeWhitelistSite(String(whitelistRow.modelData))
                      }

                      PanelToolTip {
                        visible: whitelistDeleteMouse.containsMouse
                        text: "Remove from whitelist"
                        fontFamily: root.bar.fontFamily
                      }
                    }
                  }
                }

                ScrollBar.vertical: ScrollBar {}
              }
            }

            RowLayout {
              visible: root.whitelistExpanded
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: whitelistField
                Layout.fillWidth: true
                placeholderText: "Paste a website URL"
                foreground: root.bar.foreground
                onAccepted: root.addWhitelistSite()
              }

              Button {
                text: "Add"
                iconText: "󰐕"
                bordered: true
                active: true
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: root.addWhitelistSite()
              }
            }
          }

          SpacedRule {}

          Item {
            visible: root.permanentEnabled
            width: parent.width
            implicitHeight: Math.max(permanentIcon.implicitHeight, permanentLabels.implicitHeight)

            Text {
              id: permanentIcon
              text: "󰌾"
              color: Qt.darker(root.bar.foreground, 1.5)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: permanentLabels
              anchors.left: permanentIcon.right
              anchors.leftMargin: Style.space(8)
              anchors.right: parent.right
              spacing: Style.space(1)

              Text {
                width: parent.width
                text: "Persistent protection"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.bodySmall
                font.bold: true
              }

              Text {
                width: parent.width
                text: "1M+ adult domains · updated feeds · always on"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
          }

          Item {
            visible: !root.permanentEnabled
            width: parent.width
            implicitHeight: Math.max(adultOptInLabel.implicitHeight, adultEnableButton.implicitHeight)

            Text {
              id: adultOptInLabel
              text: "Persistent Adult Site Blocker"
              color: Qt.darker(root.bar.foreground, 1.35)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.bodySmall
              font.bold: true
              anchors.left: parent.left
              anchors.right: adultEnableButton.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              elide: Text.ElideRight
            }

            Button {
              id: adultEnableButton
              text: root.adultEnableArmed ? "CONFIRM" : "Enable"
              bordered: true
              active: root.adultEnableArmed
              enabled: !root.busy
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.caption
              horizontalPadding: Style.space(8)
              verticalPadding: Style.space(2)
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              onClicked: root.enablePermanentAdult()
            }
          }
        }

        Text {
          visible: root.statusMessage !== "" && !root.passwordIncorrect
          width: parent.width
          text: root.statusMessage
          wrapMode: Text.WordWrap
          color: root.statusMessage.toLowerCase().indexOf("incorrect") >= 0
            ? root.bar.urgent
            : Qt.darker(root.bar.foreground, 1.35)
          font.family: root.bar.fontFamily
          font.pixelSize: Style.font.caption
        }

        Item { width: parent.width; height: Style.space(2) }
      }
    }
  }
}
