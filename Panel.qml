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

  property bool installed: false
  property bool clarityActive: false
  property bool manualEnabled: true
  property bool scheduleEnabled: false
  property string scheduleStart: "09:00"
  property string scheduleEnd: "17:00"
  property bool permanentEnabled: false
  property int permanentCount: 0
  property int distractionCount: 0
  property int aiAllowCount: 0
  property string adultUpdated: ""
  property string reason: "Setup required"
  property string statusMessage: ""
  property string pendingAction: ""
  property string pendingSecret: ""
  property bool cursorActive: false
  property string focusSection: "header"

  readonly property bool busy: actionProc.running
  readonly property string cli: localPath(Qt.resolvedUrl("bin/clarityctl"))
  readonly property string setupLauncher: localPath(Qt.resolvedUrl("bin/clarity-setup"))
  readonly property string icon: root.clarityActive ? "󰌵" : "󰛑"
  readonly property string heroTitle: root.installed ? "Clarity" : "Clarity Setup"
  readonly property string heroMeta: {
    if (!root.installed) return "ACTIVATE TO BEGIN"
    if (root.clarityActive) return "DISTRACTIONS BLOCKED"
    return "SOCIAL WINDOW OPEN"
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

  function refresh() {
    if (!statusProc.running) statusProc.running = true
  }

  function updateState(raw) {
    try {
      var state = JSON.parse(String(raw || "{}"))
      installed = state.installed === true
      clarityActive = state.active === true
      manualEnabled = state.manualEnabled !== false
      scheduleEnabled = state.scheduleEnabled === true
      scheduleStart = String(state.scheduleStart || "09:00")
      scheduleEnd = String(state.scheduleEnd || "17:00")
      permanentEnabled = state.permanentEnabled === true
      permanentCount = Number(state.permanentCount || 0)
      distractionCount = Number(state.distractionCount || 0)
      aiAllowCount = Number(state.aiAllowCount || 0)
      adultUpdated = String(state.adultUpdated || "")
      reason = String(state.reason || "")
      if (!startField.activeFocus) startField.text = scheduleStart
      if (!endField.activeFocus) endField.text = scheduleEnd
    } catch (error) {
      installed = false
      clarityActive = false
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
    pendingAction = ""
    pendingSecret = ""
    passwordField.text = ""
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
    actionProc.command = [root.cli].concat(args).concat(["--password-stdin"])
    actionProc.running = true
  }

  function toggleClarity() {
    if (busy) return
    if (!installed) {
      launchInstaller()
      return
    }
    if (clarityActive) requestPassword("disable")
    else if (scheduleEnabled) statusMessage = "The daily schedule controls Clarity right now."
    else runAction(["on"])
  }

  function toggleSchedule() {
    if (!installed || busy) return
    requestPassword(scheduleEnabled ? "schedule-disable" : "schedule-enable")
  }

  function saveSchedule() {
    if (!installed || busy) return
    requestPassword("schedule-save")
  }

  function submitPassword() {
    if (passwordField.text === "" || busy) return
    var secret = passwordField.text
    passwordField.text = ""
    if (pendingAction === "disable") {
      runProtected(["off"], secret)
    } else if (pendingAction === "schedule-enable") {
      runProtected(["schedule", "enabled", startField.text, endField.text], secret)
    } else if (pendingAction === "schedule-disable") {
      runProtected(["schedule", "disabled", startField.text, endField.text], secret)
    } else if (pendingAction === "schedule-save") {
      runProtected(["schedule", scheduleEnabled ? "enabled" : "disabled", startField.text, endField.text], secret)
    }
  }

  function launchInstaller() {
    root.close()
    Quickshell.execDetached([root.setupLauncher])
  }

  function editSites() {
    root.close()
    Quickshell.execDetached(["omarchy-launch-floating-terminal-with-presentation", root.cli, "sites", "edit"])
  }

  function close() {
    root.controller.hide()
    cancelPassword()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  Component.onCompleted: refresh()

  onOpenedChanged: {
    if (opened) {
      refresh()
      cursorActive = false
      focusSection = "header"
    } else {
      cancelPassword()
    }
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
        root.installed = false
        root.clarityActive = false
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
      var output = String(exitCode === 0 ? actionStdout.text : actionStderr.text).trim()
      root.statusMessage = output.replace(/^clarity:\s*/, "")
      root.pendingSecret = ""
      passwordField.text = ""
      root.refresh()
      if (exitCode === 0) {
        root.pendingAction = ""
        Qt.callLater(function() { if (keyCatcher) keyCatcher.forceActiveFocus() })
      } else {
        Qt.callLater(function() { passwordField.forceActiveFocus() })
      }
    }
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
        if (dy > 0) root.focusSection = root.focusSection === "header" ? "schedule" : "sites"
        else if (dy < 0) root.focusSection = root.focusSection === "sites" ? "schedule" : "header"
      }
      onActivateRequested: {
        if (!root.cursorActive) return
        if (root.focusSection === "header") root.toggleClarity()
        else if (root.focusSection === "schedule") root.toggleSchedule()
        else root.editSites()
      }
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: panelColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // Wi-Fi-style hero: icon · title/status · primary switch.
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

          ToggleSwitch {
            id: claritySwitch
            visible: true
            checked: root.installed ? root.clarityActive : false
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

            PanelToolTip {
              visible: claritySwitch.containsMouse
              text: !root.installed
                ? "Activate Clarity"
                : root.clarityActive ? "Clarity password required to turn off" : "Turn Clarity on"
              fontFamily: root.bar.fontFamily
            }
          }

          Column {
            id: heroLabels
            anchors.left: heroIcon.right
            anchors.leftMargin: Style.space(14)
            anchors.right: parent.right
            anchors.rightMargin: claritySwitch.visible ? claritySwitch.width + Style.space(12) : 0
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
          visible: !root.installed
          width: parent.width
          text: "ACTIVATE"
          iconText: "󰐥"
          bordered: true
          foreground: root.bar.foreground
          fontFamily: root.bar.fontFamily
          onClicked: root.launchInstaller()
        }

        Column {
          visible: true
          enabled: root.installed
          opacity: root.installed ? 1.0 : 0.35
          width: parent.width
          spacing: Style.space(8)

          Text {
            width: parent.width
            text: root.reason
            color: Qt.darker(root.bar.foreground, 1.4)
            font.family: root.bar.fontFamily
            font.pixelSize: Style.font.bodySmall
            elide: Text.ElideRight
          }

          PanelSeparator { foreground: root.bar.foreground }

          Item {
            width: parent.width
            implicitHeight: Math.max(permanentIcon.implicitHeight, permanentLabels.implicitHeight)

            Text {
              id: permanentIcon
              text: root.permanentEnabled ? "󰌾" : "󰚌"
              color: root.bar.foreground
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.subtitle
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: permanentLabels
              anchors.left: permanentIcon.right
              anchors.leftMargin: Style.space(10)
              anchors.right: parent.right
              spacing: Style.space(2)

              Text {
                width: parent.width
                text: !root.installed
                  ? "Permanent protection"
                  : root.permanentEnabled ? "Permanent protection" : "Permanent blacklist skipped"
                color: root.bar.foreground
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.body
                font.bold: true
              }
              Text {
                width: parent.width
                text: !root.installed
                  ? "Adult-domain blocking setup choice"
                  : root.permanentEnabled
                    ? root.compactNumber(root.permanentCount) + " adult domains · merged feeds · always on"
                    : "Opted out during first setup"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
                elide: Text.ElideRight
              }
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(scheduleHeader.implicitHeight, scheduleSwitch.implicitHeight)

              PanelSectionHeader {
                id: scheduleHeader
                text: "DAILY FOCUS WINDOW"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              ToggleSwitch {
                id: scheduleSwitch
                checked: root.scheduleEnabled
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

                PanelToolTip {
                  visible: scheduleSwitch.containsMouse
                  text: "Clarity password required"
                  fontFamily: root.bar.fontFamily
                }
              }
            }

            RowLayout {
              width: parent.width
              spacing: Style.space(8)

              TextField {
                id: startField
                Layout.fillWidth: true
                placeholderText: "09:00"
                inputMask: "99:99"
                horizontalAlignment: TextInput.AlignHCenter
                foreground: root.bar.foreground
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
                placeholderText: "17:00"
                inputMask: "99:99"
                horizontalAlignment: TextInput.AlignHCenter
                foreground: root.bar.foreground
              }

              Button {
                text: "Save"
                bordered: true
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
                fontSize: Style.font.bodySmall
                onClicked: root.saveSchedule()
              }
            }

            Text {
              width: parent.width
              text: "Clarity is ON inside this window and OFF outside it. Overnight windows are supported."
              wrapMode: Text.WordWrap
              color: Qt.darker(root.bar.foreground, 1.55)
              font.family: root.bar.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          PanelSeparator { foreground: root.bar.foreground }

          Item {
            width: parent.width
            implicitHeight: Math.max(sitesLabels.implicitHeight, editSitesButton.implicitHeight)

            Column {
              id: sitesLabels
              anchors.left: parent.left
              anchors.right: editSitesButton.left
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              PanelSectionHeader {
                text: "DISTRACTING SITES"
                foreground: root.bar.foreground
                fontFamily: root.bar.fontFamily
              }
              Text {
                width: parent.width
                text: !root.installed
                  ? "Massive output-killer feeds · AI tools protected"
                  : root.compactNumber(root.distractionCount) + " output killers · "
                    + root.aiAllowCount + " AI domains protected"
                color: Qt.darker(root.bar.foreground, 1.5)
                font.family: root.bar.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Button {
              id: editSitesButton
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              text: "Edit list"
              iconText: "󰏫"
              bordered: true
              hasCursor: root.cursorActive && root.focusSection === "sites"
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              fontSize: Style.font.bodySmall
              onHovered: function(on) {
                if (!on) return
                root.cursorActive = true
                root.focusSection = "sites"
              }
              onClicked: root.editSites()
            }
          }
        }

        Column {
          visible: root.pendingAction !== ""
          width: parent.width
          spacing: Style.space(8)

          PanelSeparator { foreground: root.bar.foreground }

          PanelSectionHeader {
            text: "CLARITY PASSWORD"
            foreground: root.bar.foreground
            fontFamily: root.bar.fontFamily
          }

          TextField {
            id: passwordField
            width: parent.width
            password: true
            placeholderText: "Not your Linux password"
            foreground: root.bar.foreground
            onAccepted: root.submitPassword()
            Keys.onEscapePressed: root.cancelPassword()
          }

          Row {
            anchors.right: parent.right
            spacing: Style.space(8)

            Button {
              text: "Cancel"
              bordered: true
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.cancelPassword()
            }
            Button {
              text: root.busy ? "Checking…" : "Confirm"
              bordered: true
              active: true
              foreground: root.bar.foreground
              fontFamily: root.bar.fontFamily
              onClicked: root.submitPassword()
            }
          }
        }

        Text {
          visible: root.statusMessage !== ""
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
