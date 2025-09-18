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
import QtQuick.Controls 2.4
import SddmComponents 2.0

Rectangle {
    width: 640
    height: 480

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
                        sddm.login(username.text, password.text, sessionButton.currentIndex)
                    }
                }
            }

            Row {
                width: 300
                spacing: 10

                Rectangle {
                    id: loginButton
                    width: 200
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
                            sddm.login(username.text, password.text, sessionButton.currentIndex)
                        }
                    }

                    Keys.onReturnPressed: {
                        errorMessage.text = ""
                        sddm.login(username.text, password.text, sessionButton.currentIndex)
                    }
                    Keys.onEnterPressed: {
                        errorMessage.text = ""
                        sddm.login(username.text, password.text, sessionButton.currentIndex)
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
                    property int currentIndex: 0
                    property var sessionNames: []
                    width: 90
                    height: 40
                    color: "${colors.base02}"
                    border.color: "${colors.base0D}"
                    border.width: 2
                    radius: 8

                    Text {
                        anchors.centerIn: parent
                        text: sessionButton.sessionNames.length > 0 ? sessionButton.sessionNames[sessionButton.currentIndex] : "Session"
                        color: "${colors.base07}"
                        font.pixelSize: 10
                        elide: Text.ElideRight
                        width: parent.width - 8
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: {
                            if (mouse.button === Qt.LeftButton) {
                                // Left click: next session
                                sessionButton.currentIndex = (sessionButton.currentIndex + 1) % sessionButton.sessionNames.length
                            } else if (mouse.button === Qt.RightButton) {
                                // Right click: previous session
                                sessionButton.currentIndex = (sessionButton.currentIndex - 1 + sessionButton.sessionNames.length) % sessionButton.sessionNames.length
                            }
                        }
                    }

                    Component.onCompleted: {
                        // Get actual sessions from SDDM - accessing data properly
                        if (typeof sessionModel !== "undefined" && sessionModel.count > 0) {
                            var sessions = []
                            for (var i = 0; i < sessionModel.count; i++) {
                                // Try different ways to access the model data
                                var item = sessionModel.data(sessionModel.index(i, 0), Qt.DisplayRole)
                                if (item) {
                                    sessions.push(item)
                                } else {
                                    // Fallback to just using index names
                                    sessions.push("Hyprland")
                                }
                            }
                            if (sessions.length > 0) {
                                sessionButton.sessionNames = sessions
                                sessionButton.currentIndex = sessionModel.lastIndex || 0
                            }
                        }
                        // If no sessions detected, leave empty array - shows "Session"
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
