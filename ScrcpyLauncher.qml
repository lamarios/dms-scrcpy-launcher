import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property var devices: []
    property string status: ""
    property bool screenOff: false
    property bool stayAwake: true
    property bool alwaysOnTop: false

    popoutWidth: 360
    popoutHeight: 440

    function refresh() {
        if (!lister.running)
            lister.running = true
    }

    function parseDevices(text) {
        const out = []
        for (const line of text.split("\n").slice(1)) {
            const m = line.trim().match(/^(\S+)\s+(device|unauthorized|offline)\b(.*)$/)
            if (!m) continue
            const model = (m[3].match(/model:(\S+)/) || [])[1] || m[1]
            out.push({ serial: m[1], state: m[2], name: model.replace(/_/g, " ") })
        }
        devices = out
    }

    function launch(serial) {
        const args = ["scrcpy", "-s", serial]
        if (screenOff) args.push("--turn-screen-off")
        if (stayAwake) args.push("--stay-awake")
        if (alwaysOnTop) args.push("--always-on-top")
        Quickshell.execDetached(args)
        closePopout()
    }

    function connectWifi(target) {
        if (!target || connector.running) return
        connector.target = target
        status = "Connecting..."
        connector.running = true
    }

    Process {
        id: lister
        command: ["adb", "devices", "-l"]
        stdout: StdioCollector {
            onStreamFinished: root.parseDevices(text)
        }
    }

    Process {
        id: connector
        property string target: ""
        command: ["adb", "connect", target]
        stdout: StdioCollector {
            onStreamFinished: {
                root.status = text.trim()
                root.refresh()
            }
        }
    }

    component ToggleRow: Rectangle {
        id: row
        property string label: ""
        property bool checked: false
        signal toggled()

        width: parent.width
        height: 36
        radius: Theme.cornerRadius
        color: Theme.surfaceContainerHigh

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            color: Theme.surfaceText
        }
        DankIcon {
            anchors.right: parent.right
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            name: row.checked ? "check_box" : "check_box_outline_blank"
            size: 20
            color: row.checked ? Theme.primary : Theme.surfaceVariantText
        }
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
    }

    horizontalBarPill: Component {
        DankIcon {
            name: "smartphone"
            size: Theme.iconSize - 6
            color: Theme.primary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    verticalBarPill: Component {
        DankIcon {
            name: "smartphone"
            size: Theme.iconSize - 6
            color: Theme.primary
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "Scrcpy"
            detailsText: "Mirror & control your phone"
            showCloseButton: true

            Component.onCompleted: root.refresh()

            Column {
                width: parent.width
                spacing: Theme.spacingS

                // Devices
                Row {
                    width: parent.width
                    StyledText {
                        width: parent.width - 28
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.devices.length ? "Devices" : "No devices found"
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                    }
                    DankIcon {
                        name: "refresh"
                        size: 20
                        color: Theme.surfaceText
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.refresh()
                        }
                    }
                }

                Repeater {
                    model: root.devices
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool ready: modelData.state === "device"

                        width: parent.width
                        height: 48
                        radius: Theme.cornerRadius
                        color: ready ? Theme.primaryContainer : Theme.surfaceContainerHigh
                        opacity: ready ? 1 : 0.6

                        DankIcon {
                            id: devIcon
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            name: modelData.serial.indexOf(":") >= 0 ? "wifi" : "usb"
                            size: 20
                            color: Theme.surfaceText
                        }
                        Column {
                            anchors.left: devIcon.right
                            anchors.leftMargin: Theme.spacingM
                            anchors.verticalCenter: parent.verticalCenter
                            StyledText {
                                text: modelData.name
                                color: Theme.surfaceText
                            }
                            StyledText {
                                text: parent.parent.ready ? modelData.serial : modelData.state
                                color: Theme.surfaceVariantText
                                font.pixelSize: Theme.fontSizeSmall
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: parent.ready
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.launch(modelData.serial)
                        }
                    }
                }

                // Options
                ToggleRow {
                    label: "Turn phone screen off"
                    checked: root.screenOff
                    onToggled: root.screenOff = !root.screenOff
                }
                ToggleRow {
                    label: "Stay awake"
                    checked: root.stayAwake
                    onToggled: root.stayAwake = !root.stayAwake
                }
                ToggleRow {
                    label: "Always on top"
                    checked: root.alwaysOnTop
                    onToggled: root.alwaysOnTop = !root.alwaysOnTop
                }

                // Wireless
                Rectangle {
                    width: parent.width
                    height: 40
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    TextInput {
                        id: ipInput
                        anchors.left: parent.left
                        anchors.right: connectBtn.left
                        anchors.leftMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.surfaceText
                        clip: true
                        selectByMouse: true
                        onAccepted: root.connectWifi(text.trim())

                        StyledText {
                            visible: !ipInput.text && !ipInput.activeFocus
                            text: "192.168.x.x:5555"
                            color: Theme.surfaceVariantText
                        }
                    }
                    DankIcon {
                        id: connectBtn
                        anchors.right: parent.right
                        anchors.rightMargin: Theme.spacingM
                        anchors.verticalCenter: parent.verticalCenter
                        name: "link"
                        size: 20
                        color: Theme.primary
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.connectWifi(ipInput.text.trim())
                        }
                    }
                }

                StyledText {
                    visible: root.status !== ""
                    width: parent.width
                    text: root.status
                    wrapMode: Text.Wrap
                    color: Theme.surfaceVariantText
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
        }
    }
}
