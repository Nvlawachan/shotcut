import QtQuick 2.0
import QtQml.Models 2.1
import QtQuick.Controls 1.0

Rectangle {
    id: root
    SystemPalette { id: activePalette }
    color: activePalette.window

    property int headerWidth: 120
    property int trackHeight: 50
    property real scaleFactor: 1.0

    Row {
        Column {
            z: 1
            Rectangle {
                id: toolbar
                height: ruler.height
                width: headerWidth
                z: 1
                color: activePalette.window
                Row {
                    spacing: 6
                    Item {
                        width: 1
                        height: 1
                    }
                    Button {
                        id: menuButton
                        implicitWidth: 28
                        implicitHeight: 24
                        iconName: 'format-justify-fill'
                        onClicked: menu.popup()
                    }
                }
            }
            Flickable {
                // Non-slider scroll area for the track headers.
                contentY: scrollView.flickableItem.contentY
                width: headerWidth
                height: trackHeaders.height
                interactive: false
                focus: false

                Column {
                    id: trackHeaders
                    Repeater {
                        model: multitrack
                        TrackHead {
                            trackName: model.name
                            isMute: model.mute
                            isHidden: model.hidden
                            isVideo: !model.audio
                            color: (index % 2)? activePalette.alternateBase : activePalette.base
                            width: headerWidth
                            height: model.audio? trackHeight : trackHeight * 2
                            onTrackNameChanged: {
                                if (isEditing)
                                    multitrack.setTrackName(index, trackName)
                                isEditing = false
                            }
                            onMuteClicked: {
                                multitrack.setTrackMute(index, isMute)
                            }
                            onHideClicked: {
                                multitrack.setTrackHidden(index, isHidden)
                            }
                        }
                    }
                }   
            }
            Rectangle {
                color: activePalette.window
                height: root.height - trackHeaders.height - ruler.height + 4
                width: headerWidth
                Slider {
                    id: scaleSlider
                    orientation: Qt.Horizontal
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        leftMargin: 4
                        rightMargin: 4
                    }
                    minimumValue: 0.1
                    maximumValue: 5.0
                    value: 4.0
                    onValueChanged: {
                        if (typeof root.scaleFactor != 'undefined')
                            root.scaleFactor = (value <= 4) ? value / 4 : 1.0 + (value - 4) * 2
                        if (typeof scrollIfNeeded != 'undefined')
                            scrollIfNeeded()
                    }
                }
            }
        }

        MouseArea {
            width: root.width - headerWidth
            height: root.height

            // This provides continuous scrubbing and scimming at the left/right edges.
            focus: true
            hoverEnabled: true
            property bool scim: false
            Keys.onPressed: scim = (event.modifiers === Qt.ShiftModifier)
            Keys.onReleased: scim = false
            onReleased: scrubTimer.stop()
            onMouseXChanged: {
                if (scim || pressedButtons === Qt.LeftButton) {
                    timeline.position = (scrollView.flickableItem.contentX + mouse.x) / scaleFactor
                    if ((mouse.x < 50) || (mouse.x > scrollView.width - 50))
                        scrubTimer.start()
                }
            }
            Timer {
                id: scrubTimer
                interval: 25
                repeat: true
                onTriggered: {
                    if (parent.scim || parent.pressedButtons === Qt.LeftButton) {
                        if (parent.mouseX < 50)
                            timeline.position -= 10
                        else if (parent.mouseX > scrollView.flickableItem.contentX - 50)
                            timeline.position += 10
                    }
                    if (parent.mouseX >= 50 && parent.mouseX <= scrollView.width - 50)
                        stop()
                }
            }
        

            Column {
                Flickable {
                    // Non-slider scroll area for the Ruler.
                    contentX: scrollView.flickableItem.contentX
                    width: root.width - headerWidth
                    height: ruler.height
                    interactive: false
                    focus: false
                    Ruler {
                        id: ruler
                        width: tracksContainer.width
                        index: index
                        timeScale: scaleFactor
                    }
                }
                ScrollView {
                    id: scrollView
                    width: root.width - headerWidth
                    height: root.height - ruler.height
                    focus: false
        
                    Item {
                        width: tracksContainer.width + headerWidth
                        height: trackHeaders.height + 30 // 30 is padding
                        Column {
                            // These make the striped background for the tracks.
                            // It is important that these are not part of the track visual hierarchy;
                            // otherwise, the clips will be obscured by the Track's background.
                            Repeater {
                                model: multitrack
                                delegate: Rectangle {
                                    width: tracksContainer.width
                                    color: (index % 2)? activePalette.alternateBase : activePalette.base
                                    height: audio? trackHeight : trackHeight * 2
                                }
                            }
                        }
                        Column {
                            id: tracksContainer
                            Repeater { id: tracksRepeater; model: trackDelegateModel }
                        }
                    }
                }
            }
            Rectangle {
                id: cursor
                visible: timeline.position > -1
                color: activePalette.text
                width: 1
                height: root.height - scrollView.__horizontalScrollBar.height
                x: timeline.position * scaleFactor - scrollView.flickableItem.contentX
                y: 0
            }
            Canvas {
                id: playhead
                visible: timeline.position > -1
                x: timeline.position * scaleFactor - scrollView.flickableItem.contentX - 5
                y: 0
                width: 11
                height: 5
                property bool init: true
                onPaint: {
                    if (init) {
                        init = false;
                        var cx = getContext('2d');
                        cx.fillStyle = activePalette.windowText;
                        cx.beginPath();
                        // Start from the root-left point.
                        cx.lineTo(width, 0);
                        cx.lineTo(width / 2.0, height);
                        cx.lineTo(0, 0);
                        cx.fill();
                        cx.closePath();
                    }
                }
            }
        }
    }

    Menu {
        id: menu
        MenuItem {
            text: qsTr('New')
        }
    }

    DelegateModel {
        id: trackDelegateModel
        model: multitrack
        Track {
            model: multitrack
            rootIndex: trackDelegateModel.modelIndex(index)
            height: audio? trackHeight : trackHeight * 2
            width: childrenRect.width
            isAudio: audio
            timeScale: scaleFactor
            onClipSelected: {
                for (var i = 0; i < tracksRepeater.count; i++)
                    if (i !== track.DelegateModel.itemsIndex) tracksRepeater.itemAt(i).resetStates();
            }
            onClipDragged: {
                // This provides continuous scrolling at the left/right edges.
                if (x > scrollView.flickableItem.contentX + scrollView.width - 50) {
                    scrollTimer.item = clip
                    scrollTimer.backwards = false
                    scrollTimer.start()
                } else if (x < 50) {
                    scrollView.flickableItem.contentX = 0;
                    scrollTimer.stop()
                } else if (x < scrollView.flickableItem.contentX + 50) {
                    scrollTimer.item = clip
                    scrollTimer.backwards = true
                    scrollTimer.start()
                } else {
                    scrollTimer.stop()
                }
            }
            onClipDropped: scrollTimer.running = false
            onClipDraggedToTrack: {
                var i = clip.trackIndex + direction
                if (i >= 0  && i < tracksRepeater.count) {
                    var track = tracksRepeater.itemAt(i)
                    clip.reparent(track)
                    clip.trackIndex = track.DelegateModel.itemsIndex
                }
            }
        }
    }
    
    Connections {
        target: timeline
        onPositionChanged: scrollIfNeeded()
    }

    // This provides continuous scrolling at the left/right edges.
    Timer {
        id: scrollTimer
        interval: 25
        repeat: true
        triggeredOnStart: true
        property var item
        property bool backwards
        onTriggered: {
            var delta = backwards? -10 : 10
            if (item) item.x += delta
            scrollView.flickableItem.contentX += delta
            if (scrollView.flickableItem.contentX <= 0)
                stop()
        }
    }

    function scrollIfNeeded() {
        var x = timeline.position * scaleFactor;
        if (x > scrollView.flickableItem.contentX + scrollView.width - 50)
            scrollView.flickableItem.contentX = x - scrollView.width + 50;
        else if (x < 50)
            scrollView.flickableItem.contentX = 0;
        else if (x < scrollView.flickableItem.contentX + 50)
            scrollView.flickableItem.contentX = x - 50;
    }
}
