{pkgs}: let
  # Use atomic-terracotta colors and wallpaper from stylix config
  image = ../../../homeManagerModules/features/stylix/atomic-terracotta-canyon.jpeg;

  # atomic-terracotta base16 colors (matching stylix config)
  colors = {
    base00 = "#1a1a1a"; # Dark background
    base01 = "#2d2d2d"; # Lighter background
    base02 = "#3d3d3d"; # Selection background
    base03 = "#4a4a4a"; # Comments/disabled
    base04 = "#b8b8b8"; # Dark foreground
    base05 = "#d4d4d4"; # Default foreground
    base06 = "#e8e8e8"; # Light foreground
    base07 = "#f5f5f5"; # Lightest foreground
    base08 = "#b7410e"; # Rust red-orange
    base09 = "#a0522d"; # Sienna
    base0A = "#cd853f"; # Peru/golden rod
    base0B = "#74a478"; # Green
    base0C = "#4d9494"; # Cyan/teal
    base0D = "#6ba6cd"; # Blue
    base0E = "#a47996"; # Purple/magenta
    base0F = "#8b4513"; # Saddle brown
  };
in
  pkgs.runCommand "sddm-atomic-terracotta-theme" {} ''
      mkdir -p $out
      cd $out/

      # Copy background image
      cp ${image} Background.jpg

      # Create a simple, clean SDDM theme from scratch
      cat > theme.conf << EOF
[General]
Background="${image}"
DimBackgroundImage="0.0"
ScaleImageCropped=true
ScreenWidth=1920
ScreenHeight=1080

[Input]
Font="JetBrainsMono Nerd Font"
FontSize=16
Radius=10
BackgroundColor="${colors.base01}"
BackgroundOpacity=0.95
TextColor="${colors.base07}"
BorderColor="${colors.base0D}"
FocusBorderColor="${colors.base09}"
PlaceholderTextColor="${colors.base05}"

[UserPicture]
BorderColor="${colors.base0D}"
BorderWidth=3
Radius=60

[Button]
BackgroundColor="${colors.base08}"
TextColor="${colors.base07}"
BorderColor="${colors.base0A}"
BorderWidth=2
Radius=10
FontSize=14

[Text]
TextColor="${colors.base07}"
BackgroundColor="${colors.base01}"
FontSize=18
EOF

      # Create simple Main.qml without user silhouette
      cat > Main.qml << 'QMLEOF'
import QtQuick 2.11
import SddmComponents 2.0

Rectangle {
    width: 640
    height: 480
    property int sessionIndex: 0
    property var filteredSessions: []
    property var sessionMapping: []  // Maps filtered index to real sessionModel index

    // Create a ListView to access session data like ComboBox does
    ListView {
        id: hiddenSessionList
        visible: false
        width: 0
        height: 0
        model: sessionModel
        delegate: Item {
            property variant modelItem: model
        }
    }

    Image {
        anchors.fill: parent
        source: "Background.jpg"
        fillMode: Image.PreserveAspectCrop
    }

    Rectangle {
        anchors.centerIn: parent
        width: 400
        height: 320
        color: "${colors.base01}"
        opacity: 0.9
        radius: 10

        Column {
            anchors.centerIn: parent
            spacing: 20

            // Clock with seconds
            Text {
                id: clock
                color: "${colors.base07}"
                font.pixelSize: 18
                anchors.horizontalCenter: parent.horizontalCenter

                Timer {
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        var now = new Date()
                        clock.text = Qt.formatTime(now, "hh:mm:ss")
                    }
                }
                Component.onCompleted: {
                    var now = new Date()
                    clock.text = Qt.formatTime(now, "hh:mm:ss")
                }
            }

            Text {
                text: "Login"
                color: "${colors.base07}"
                font.pixelSize: 24
                anchors.horizontalCenter: parent.horizontalCenter
            }

            // Error message for login failures
            Text {
                id: errorMessage
                text: ""
                color: "${colors.base08}"
                font.pixelSize: 14
                anchors.horizontalCenter: parent.horizontalCenter
                visible: text.length > 0
                wrapMode: Text.WordWrap
                width: 280
            }

            Rectangle {
                id: usernameRect
                width: 300
                height: 40
                color: "${colors.base00}"
                border.color: "${colors.base0D}"
                border.width: 2
                radius: 8

                TextInput {
                    id: username
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "${colors.base07}"
                    font.pixelSize: 16
                    verticalAlignment: TextInput.AlignVCenter
                    focus: true

                    KeyNavigation.tab: password
                    KeyNavigation.backtab: loginButton

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Username"
                        color: "${colors.base04}"
                        font.pixelSize: 16
                        visible: username.text.length === 0
                    }
                }
            }

            Rectangle {
                id: passwordRect
                width: 300
                height: 40
                color: "${colors.base00}"
                border.color: "${colors.base0D}"
                border.width: 2
                radius: 8

                TextInput {
                    id: password
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "${colors.base07}"
                    font.pixelSize: 16
                    echoMode: TextInput.Password
                    verticalAlignment: TextInput.AlignVCenter

                    KeyNavigation.tab: loginButton
                    KeyNavigation.backtab: username

                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Password"
                        color: "${colors.base04}"
                        font.pixelSize: 16
                        visible: password.text.length === 0
                    }

                    onAccepted: {
                        errorMessage.text = ""
                        var realIndex = sessionMapping[sessionIndex] || 0
                        sddm.login(username.text, password.text, realIndex)
                    }
                }
            }

            Row {
                width: 300
                spacing: 10

                Rectangle {
                    id: loginButton
                    width: 120
                    height: 40
                    color: "${colors.base08}"
                    border.color: "${colors.base0A}"
                    border.width: 2
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: "Login"
                        color: "${colors.base07}"
                        font.pixelSize: 16
                    }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            errorMessage.text = ""
                            var realIndex = sessionMapping[sessionIndex] || 0
                            sddm.login(username.text, password.text, realIndex)
                        }
                    }

                    Keys.onReturnPressed: {
                        errorMessage.text = ""
                        var realIndex = sessionMapping[sessionIndex] || 0
                        sddm.login(username.text, password.text, realIndex)
                    }
                    Keys.onEnterPressed: {
                        errorMessage.text = ""
                        var realIndex = sessionMapping[sessionIndex] || 0
                        sddm.login(username.text, password.text, realIndex)
                    }
                    Keys.onTabPressed: username.focus = true
                    Keys.onBacktabPressed: password.focus = true

                    onFocusChanged: {
                        if (focus) {
                            loginButton.forceActiveFocus()
                        }
                    }
                }

                Rectangle {
                    id: sessionButton
                    width: 170
                    height: 40
                    color: "${colors.base02}"
                    border.color: "${colors.base0D}"
                    border.width: 2
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: {
                            // Use the same approach as ComboBox to get the session name
                            if (typeof sessionModel !== "undefined" && sessionModel.count > 0) {
                                var realIdx = sessionMapping[sessionIndex] || 0
                                if (realIdx < sessionModel.count) {
                                    hiddenSessionList.currentIndex = realIdx
                                    if (hiddenSessionList.currentItem && hiddenSessionList.currentItem.modelItem) {
                                        var sessionName = hiddenSessionList.currentItem.modelItem.name || ""
                                        // Clean up the display name
                                        if (sessionName.indexOf("Hyprland") >= 0) {
                                            return "Hyprland"
                                        } else if (sessionName.indexOf("Xorg") >= 0 || sessionName.indexOf("xorg") >= 0) {
                                            return "GNOME on Xorg"
                                        } else if (sessionName.indexOf("GNOME") >= 0 || sessionName.indexOf("gnome") >= 0) {
                                            return "GNOME"
                                        }
                                        return sessionName
                                    }
                                }
                            }
                            // Only show this during initial loading
                            return "Loading..."
                        }
                        color: "${colors.base07}"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        width: parent.width - 10
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: {
                            if (filteredSessions.length > 0) {
                                if (mouse.button === Qt.LeftButton) {
                                    sessionIndex = (sessionIndex + 1) % filteredSessions.length
                                } else if (mouse.button === Qt.RightButton) {
                                    sessionIndex = (sessionIndex - 1 + filteredSessions.length) % filteredSessions.length
                                }
                            }
                        }
                    }

                    Component.onCompleted: {
                        if (typeof sessionModel !== "undefined" && sessionModel.count > 0) {
                            var allSessions = []

                            // Get all session names by cycling through the ListView
                            for (var i = 0; i < sessionModel.count; i++) {
                                hiddenSessionList.currentIndex = i

                                var name = ""
                                if (hiddenSessionList.currentItem && hiddenSessionList.currentItem.modelItem) {
                                    name = hiddenSessionList.currentItem.modelItem.name || ""
                                }

                                if (!name) {
                                    // Try direct model access as fallback
                                    var item = sessionModel.get ? sessionModel.get(i) : null
                                    if (item && item.name) {
                                        name = item.name
                                    } else {
                                        name = "Session " + i
                                    }
                                }

                                allSessions.push({
                                    name: name,
                                    realIndex: i
                                })
                            }

                            // Now filter duplicates
                            var filtered = []
                            var seen = {}

                            for (var j = 0; j < allSessions.length; j++) {
                                var s = allSessions[j]
                                var key = ""

                                // Create unique key for each session type
                                if (s.name.indexOf("Hyprland") >= 0) {
                                    key = "Hyprland"
                                } else if (s.name.indexOf("Xorg") >= 0 || s.name.indexOf("xorg") >= 0) {
                                    key = "GNOME on Xorg"
                                } else if (s.name.indexOf("GNOME") >= 0 || s.name.indexOf("gnome") >= 0) {
                                    // First GNOME without Xorg is Wayland
                                    if (!seen["GNOME"]) {
                                        key = "GNOME"
                                    }
                                }

                                if (key && !seen[key]) {
                                    seen[key] = true
                                    filtered.push({
                                        name: key,
                                        realIndex: s.realIndex
                                    })
                                    sessionMapping.push(s.realIndex)
                                }
                            }

                            filteredSessions = filtered

                            // Default to GNOME (Wayland), fallback to Hyprland
                            for (var k = 0; k < filtered.length; k++) {
                                if (filtered[k].name === "GNOME") {
                                    sessionIndex = k
                                    break
                                }
                            }
                            // If GNOME not found, try Hyprland
                            if (sessionIndex === 0 && filteredSessions.length > 0) {
                                for (var k = 0; k < filtered.length; k++) {
                                    if (filtered[k].name === "Hyprland") {
                                        sessionIndex = k
                                        break
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Connect to SDDM signals for login feedback
    Connections {
        target: sddm

        onLoginFailed: {
            errorMessage.text = "Login failed. Please check your username and password."
            password.text = ""
            password.focus = true
        }

        onLoginSucceeded: {
            errorMessage.text = ""
        }
    }
}
QMLEOF
  ''
