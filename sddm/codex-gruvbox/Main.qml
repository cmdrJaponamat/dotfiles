import QtQuick 2.15
import QtQuick.Layouts 1.15
import QtQuick.Controls 2.15
import SddmComponents 2.0

Rectangle {
    id: root
    width: 1280
    height: 720

    property color bg0Hard: "#1d2021"
    property color bg0: "#282828"
    property color bg1: "#3c3836"
    property color bg3: "#665c54"
    property color fg0: "#fbf1c7"
    property color fg1: "#ebdbb2"
    property color yellow: "#d79921"
    property color blue: "#458588"
    property color aqua: "#689d6a"
    property color red: "#fb4934"
    property string uiFont: config.font && config.font.length ? config.font : "Sans Serif"

    color: bg0Hard

    TextConstants { id: textConstants }

    Connections {
        target: sddm

        function onLoginSucceeded() {
            statusMessage.color = root.aqua
            statusMessage.text = textConstants.loginSucceeded
        }

        function onLoginFailed() {
            statusMessage.color = root.red
            statusMessage.text = textConstants.loginFailed
        }
    }

    Repeater {
        model: screenModel
        Rectangle {
            x: geometry.x
            y: geometry.y
            width: geometry.width
            height: geometry.height

            gradient: Gradient {
                GradientStop { position: 0.0; color: root.bg0Hard }
                GradientStop { position: 0.55; color: root.bg0 }
                GradientStop { position: 1.0; color: root.bg1 }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: 0.18
    }

    Rectangle {
        width: Math.min(parent.width * 0.42, 540)
        height: Math.min(parent.height * 0.58, 430)
        anchors.centerIn: parent
        radius: 26
        color: "#1d2021dd"
        border.width: 2
        border.color: root.bg3
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(parent.width * 0.34, 460)
        spacing: 18

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 64

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "arch"
                color: root.yellow
                font.family: root.uiFont
                font.pixelSize: 34
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                text: "gruvbox session"
                color: root.fg1
                opacity: 0.85
                font.family: root.uiFont
                font.pixelSize: 15
            }
        }

        Text {
            Layout.fillWidth: true
            text: textConstants.welcomeText.arg(sddm.hostName)
            color: root.fg0
            font.family: root.uiFont
            font.pixelSize: 16
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }

        Text {
            Layout.fillWidth: true
            text: textConstants.userName
            color: root.fg1
            font.family: root.uiFont
            font.pixelSize: 14
        }

        TextBox {
            id: username
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            text: userModel.lastUser
            font.family: root.uiFont
            font.pixelSize: 18
            color: root.bg0
            borderColor: activeFocus ? root.yellow : root.bg3
            focusColor: root.yellow
            hoverColor: root.blue
            textColor: root.fg0

            KeyNavigation.tab: password
            KeyNavigation.backtab: loginButton

            Keys.onReturnPressed: sddm.login(username.text, password.text, session.index)
            Keys.onEnterPressed: sddm.login(username.text, password.text, session.index)
        }

        Text {
            Layout.fillWidth: true
            text: textConstants.password
            color: root.fg1
            font.family: root.uiFont
            font.pixelSize: 14
        }

        PasswordBox {
            id: password
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            font.family: root.uiFont
            font.pixelSize: 18
            color: root.bg0
            borderColor: activeFocus ? root.yellow : root.bg3
            focusColor: root.yellow
            hoverColor: root.blue
            textColor: root.fg0
            focus: true

            KeyNavigation.tab: session
            KeyNavigation.backtab: username

            Keys.onReturnPressed: sddm.login(username.text, password.text, session.index)
            Keys.onEnterPressed: sddm.login(username.text, password.text, session.index)
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            ComboBox {
                id: session
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                model: sessionModel
                index: sessionModel.lastIndex
                font.family: root.uiFont
                font.pixelSize: 16
                color: root.bg0
                borderColor: activeFocus ? root.blue : root.bg3
                focusColor: root.blue
                hoverColor: root.yellow
                textColor: root.fg0
                arrowIcon: ""

                KeyNavigation.tab: loginButton
                KeyNavigation.backtab: password
            }

            LayoutBox {
                id: layoutBox
                Layout.preferredWidth: 120
                Layout.preferredHeight: 44
                font.family: root.uiFont
                font.pixelSize: 16
                color: root.bg0
                borderColor: activeFocus ? root.blue : root.bg3
                focusColor: root.blue
                hoverColor: root.yellow
                textColor: root.fg0
                arrowIcon: ""

                KeyNavigation.tab: loginButton
                KeyNavigation.backtab: session
            }
        }

        Button {
            id: loginButton
            Layout.fillWidth: true
            Layout.preferredHeight: 50
            text: textConstants.login
            color: root.yellow
            textColor: root.bg0Hard
            borderColor: root.yellow
            pressedColor: root.blue
            activeColor: root.aqua
            font.family: root.uiFont
            font.pixelSize: 17
            font.weight: Font.DemiBold

            onClicked: sddm.login(username.text, password.text, session.index)

            KeyNavigation.tab: username
            KeyNavigation.backtab: layoutBox
        }

        Text {
            id: statusMessage
            Layout.fillWidth: true
            color: root.fg1
            opacity: text.length > 0 ? 1.0 : 0.0
            text: ""
            font.family: root.uiFont
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
        }
    }
}
