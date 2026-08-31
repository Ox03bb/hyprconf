import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets
import Quickshell.Services.Mpris

AbstractBackgroundWidget {
    id: root

    configEntryName: "music"

    // INCREASED SIZE to properly fit the larger buttons and progress canvas
    implicitWidth: 420
    implicitHeight: 200

    visibleWhenLocked: false

    property var activePlayer: {
        const players = Mpris.players.values;
        if (players.length === 0)
            return null;
        const playing = players.find(p => p.playbackState === MprisPlaybackState.Playing);
        return playing ?? players[0];
    }
    property bool hasPlayer: activePlayer !== null

    // // Base array for the spectrum
    // property var spectrumData: [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]

    // // MPRIS Time Ticker
    Timer {
        interval: 1000
        running: root.hasPlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing
        repeat: true
        onTriggered: root.activePlayer.positionChanged()
    }

    // // Spectrum Animation Simulator
    // // (Generates realistic bouncing visualizer data when music is playing)
    // Timer {
    //     interval: 100
    //     running: root.hasPlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing
    //     repeat: true
    //     onTriggered: {
    //         let newData = [];
    //         for (let i = 0; i < 15; i++) {
    //             // Creates a slight bell-curve bias so the middle bars bounce higher
    //             let multiplier = 1.0 - Math.abs((i - 7) / 7.0) * 0.4;
    //             newData.push(0.1 + (Math.random() * 0.8 * multiplier));
    //         }
    //         root.spectrumData = newData;
    //     }
    // }

    // // Flatten spectrum when paused
    // Connections {
    //     target: root.activePlayer
    //     ignoreUnknownSignals: true
    //     function onPlaybackStateChanged() {
    //         if (!root.activePlayer || root.activePlayer.playbackState !== MprisPlaybackState.Playing) {
    //             root.spectrumData = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1,];
    //         }
    //     }
    // }

    function fmtTime(sec) {
        if (!sec || sec <= 0)
            return "0:00";
        const total = Math.floor(sec);
        const m = Math.floor(total / 60);
        const s = total % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    StyledRectangularShadow {
        target: card
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding.windowRounding
        color: Appearance.colors.colLayer1
        clip: true

        // Inner Border Fix
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Appearance.rounding.windowRounding
            color: "transparent"
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            z: 10
        }

        // --- AUDIO SPECTRUM BACKGROUND ---
        Row {
            id: spectrumContainer
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: parent.height * 0.65
            spacing: 6 // slightly wider spacing
            opacity: 0.12 
            
            leftPadding: (width - (spectrumRepeater.count * 14)) / 2

            Repeater {
                id: spectrumRepeater
                model: root.spectrumData.length

                Rectangle {
                    width: 8
                    radius: 4
                    color: Appearance.colors.colPrimary
                    anchors.bottom: parent.bottom
                    height: Math.max(8, root.spectrumData[index] * spectrumContainer.height)

                    Behavior on height {
                        NumberAnimation { duration: 120; easing.type: Easing.OutQuad }
                    }
                }
            }
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 16 // Increased margins for better layout
            spacing: 16
            z: 1

            // ---- album art ----
            Rectangle {
                id: artFrame
                Layout.preferredWidth: 120 // Increased art size to match new height
                Layout.preferredHeight: 120
                Layout.alignment: Qt.AlignVCenter
                radius: Appearance.rounding.normal
                color: Appearance.colors.colLayer2
                clip: true

                Image {
                    id: artImg
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: root.hasPlayer ? (root.activePlayer.trackArtUrl ?? "") : ""
                    visible: status === Image.Ready
                }

                Text {
                    anchors.centerIn: parent
                    visible: !artImg.visible
                    text: "♪"
                    font.pixelSize: 42
                    color: Appearance.colors.colOnLayer2
                }
            }

            // ---- text + progress + transport ----
            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 6

                Text {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? (root.activePlayer.trackTitle || "Unknown title") : "Nothing playing"
                    color: Appearance.colors.colOnLayer1
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    Layout.fillWidth: true
                    text: root.hasPlayer ? (root.activePlayer.trackArtist || "Unknown artist") : "Open a player to begin"
                    color: Appearance.colors.colSubtext
                    font.family: Appearance.font.family.main
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    elide: Text.ElideRight
                }

                Item {
                    Layout.fillHeight: true
                }

                // ---- Material 3 Wavy Progress Line ----
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 20

                    Canvas {
                        id: progressCanvas
                        anchors.fill: parent

                        property real progress: (root.hasPlayer && root.activePlayer.length > 0) ? (root.activePlayer.position / root.activePlayer.length) : 0
                        property real phase: 0
                        property color waveColor: Appearance.colors.colPrimary
                        property color trackColor: Appearance.colors.colLayer2
                        
                        NumberAnimation on phase {
                            loops: Animation.Infinite
                            from: 0
                            to: Math.PI * 2
                            duration: 1500
                            running: root.hasPlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing
                        }

                        onPhaseChanged: requestPaint()
                        onProgressChanged: requestPaint()

                        onPaint: {
                            var ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);

                            var pWidth = width * Math.max(0, Math.min(1, progress));
                            var midY = height / 2;
                            var amp = 3.5;
                            var freq = 0.25;

                            ctx.lineWidth = 3;
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";

                            if (!root.hasPlayer || root.activePlayer.length <= 0) {
                                ctx.beginPath();
                                ctx.strokeStyle = trackColor;
                                ctx.moveTo(0, midY);
                                ctx.lineTo(width, midY);
                                ctx.stroke();
                                return;
                            }

                            ctx.beginPath();
                            ctx.strokeStyle = trackColor;
                            ctx.moveTo(pWidth, midY);
                            ctx.lineTo(width, midY);
                            ctx.stroke();

                            ctx.beginPath();
                            ctx.strokeStyle = waveColor;
                            for (var x = 0; x <= pWidth; x += 1) {
                                var y = midY + Math.sin((x * freq) - phase) * amp;
                                if (x === 0) ctx.moveTo(x, y);
                                else ctx.lineTo(x, y);
                            }
                            ctx.stroke();

                            var endY = midY + Math.sin((pWidth * freq) - phase) * amp;
                            ctx.beginPath();
                            ctx.fillStyle = waveColor;
                            ctx.arc(pWidth, endY, 5, 0, 2 * Math.PI);
                            ctx.fill();
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -10 
                        enabled: root.hasPlayer && root.activePlayer.canSeek
                        cursorShape: Qt.PointingHandCursor
                        onClicked: mouse => {
                            if (!root.hasPlayer || root.activePlayer.length <= 0)
                                return;
                            root.activePlayer.position = (mouse.x / width) * root.activePlayer.length;
                        }
                    }
                }

                RowLayout {
                    Layout.topMargin: -2
                    spacing: 4
                    Text {
                        text: root.hasPlayer ? root.fmtTime(root.activePlayer.position) : "0:00"
                        color: Appearance.colors.colSubtext
                        font.family: Appearance.font.family.numbers
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: root.hasPlayer ? root.fmtTime(root.activePlayer.length) : "0:00"
                        color: Appearance.colors.colSubtext
                        font.family: Appearance.font.family.numbers
                        font.pixelSize: Appearance.font.pixelSize.smallest
                    }
                }

                RowLayout {
                    Layout.topMargin: 4
                    Layout.alignment: Qt.AlignHCenter
                    spacing: 20

                    TransportButton {
                        glyph: "⏮"
                        size: 50
                        enabled: root.hasPlayer 
                        onClicked: {
                            if (!root.hasPlayer) return;
                            
                            // 1. Try to go to the previous track (works for Spotify, YT Playlists, etc.)
                            if (root.activePlayer.canGoPrevious) {
                                root.activePlayer.previous();
                            } 
                            // 2. FALLBACK for YouTube: Skip backward 10 seconds
                            else if (root.activePlayer.canSeek) {
                                // Quickshell might use seconds or microseconds. This dynamically handles both.
                                let isMicroseconds = root.activePlayer.length > 1000000;
                                let skipAmount = isMicroseconds ? 10000000 : 10; 
                                root.activePlayer.position = Math.max(0, root.activePlayer.position - skipAmount);
                            }
                        }
                    }

                    TransportButton {
                        glyph: (root.hasPlayer && root.activePlayer.playbackState === MprisPlaybackState.Playing) ? "⏸" : "▶"
                        size: 52
                        filled: true
                        enabled: root.hasPlayer && root.activePlayer.canTogglePlaying
                        onClicked: root.activePlayer.isPlaying = !root.activePlayer.isPlaying
                    }

                    TransportButton {
                        glyph: "⏭"
                        size: 50
                        enabled: root.hasPlayer 
                        onClicked: {
                            if (!root.hasPlayer) return;
                            
                            // 1. Try to go to the next track
                            if (root.activePlayer.canGoNext) {
                                root.activePlayer.next();
                            } 
                            // 2. FALLBACK for YouTube: Skip forward 10 seconds
                            else if (root.activePlayer.canSeek) {
                                let isMicroseconds = root.activePlayer.length > 1000000;
                                let skipAmount = isMicroseconds ? 10000000 : 10;
                                root.activePlayer.position = Math.min(root.activePlayer.length, root.activePlayer.position + skipAmount);
                            }
                        }
                    }
                    TransportButton {
                        glyph: "▶"
                        size: 30
                        enabled: root.hasPlayer 
                        onClicked: {
                            if (!root.hasPlayer) return;
                            
                            // 1. Try to go to the next track
                            if (root.activePlayer.canGoNext) {
                                root.activePlayer.next();
                            } 
                            // 2. FALLBACK for YouTube: Skip forward 10 seconds
                            else if (root.activePlayer.canSeek) {
                                let isMicroseconds = root.activePlayer.length > 1000000;
                                let skipAmount = isMicroseconds ? 10000000 : 100000;
                                root.activePlayer.position = Math.min(root.activePlayer.length, root.activePlayer.position + skipAmount);
                            }
                        }
                    }
                }
            }
        }
    }

    component TransportButton: Rectangle {
        id: btn
        property string glyph: ""
        property int size: 32
        property bool filled: false
        property bool enabled: true
        signal clicked()

        width: size
        height: size
        radius: Appearance.rounding.full
        color: filled ? (mouseArea.pressed ? Appearance.colors.colPrimaryActive : Appearance.colors.colPrimary) : (mouseArea.pressed ? Appearance.colors.colLayer2Active : "transparent")
        opacity: enabled ? 1.0 : 0.35

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        Text {
            anchors.centerIn: parent
            text: btn.glyph
            font.pixelSize: btn.size * 0.42
            color: btn.filled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: btn.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
        }
    }
}