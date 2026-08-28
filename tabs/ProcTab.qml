import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../Model.js" as Model
import "../components"

Column {
  id: procTabRoot

  required property var panel
  property var listModel

  component ActionPill: ActionPillComponent {
    foreground: panel.foreground
    fontFamily: panel.fontFamily
  }

  component ColumnHeader: ColumnHeaderComponent {
    activeSort: panel.sortKey === key
    sortReverse: panel.sortReverse
    foreground: panel.foreground
    faint: panel.faint
    fontFamily: panel.fontFamily
    onSortRequested: function(k) { panel.setSort(k) }
  }

  spacing: Style.space(8)

  function scrollTo(index) { procList.positionViewAtIndex(index, ListView.Contain) }
  function scrollToEdge(toEnd) { if (toEnd) procList.positionViewAtEnd(); else procList.positionViewAtBeginning() }
  function focusFilter() { filterField.forceActiveFocus(); filterField.selectAll() }
  function clearFilterField() { filterField.text = "" }

  Component.onCompleted: filterField.text = panel.filterText
  Component.onDestruction: if (panel.filtering) panel.filtering = false

  // Summary line + filter box.
  Item {
    width: parent.width
    implicitHeight: Math.max(procSummary.implicitHeight, filterField.implicitHeight)

    Text {
      id: procSummary
      text: panel.snapshot
        ? (panel.filterText !== ""
            ? Model.count(panel.sortedProcs.length) + " OF " + Model.count(panel.processes.length) + " PROCESSES"
            : Model.count(panel.snapshot.procs.total) + " PROCESSES  ·  " + Model.count(panel.snapshot.procs.threads) + " THREADS")
        : ""
      textFormat: Text.PlainText
      color: panel.faint
      font.family: panel.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 1
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
    }

    TextField {
      id: filterField
      width: Style.space(170)
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      placeholderText: "Filter  ( / )"
      foreground: panel.foreground
      font.family: panel.fontFamily
      onTextChanged: { if (text !== panel.filterText) { panel.filterText = text; panel.procIndex = 0; panel.rebuildProcs() } }
      onActiveFocusChanged: panel.filtering = activeFocus
      Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
          if (text !== "") panel.clearFilter()
          else panel.stopFiltering()
          event.accepted = true
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Down) {
          panel.stopFiltering()
          panel.cursorActive = true
          event.accepted = true
        }
      }
    }
  }

  // Column headers double as the sort controls: click to sort by
  // that column, click again to flip the direction.
  Item {
    width: parent.width
    implicitHeight: Style.space(20)

    ColumnHeader { key: "name"; text: "Name"; anchors.left: parent.left; anchors.right: pidHeader.left; anchors.rightMargin: Style.space(8) }
    ColumnHeader { id: pidHeader; key: "pid"; text: "PID"; alignRight: true; width: Style.space(58); anchors.right: userHeader.left; anchors.rightMargin: Style.space(8) }
    ColumnHeader { id: userHeader; key: "user"; text: "User"; width: Style.space(70); anchors.right: memHeader.left; anchors.rightMargin: Style.space(8) }
    ColumnHeader { id: memHeader; key: "mem"; text: "Mem"; alignRight: true; width: Style.space(58); anchors.right: cpuHeader.left; anchors.rightMargin: Style.space(8) }
    ColumnHeader { id: cpuHeader; key: "cpu"; text: "CPU"; alignRight: true; width: Style.space(58); anchors.right: parent.right }
  }

  ListView {
    id: procList
    width: parent.width
    // A whole number of rows, so the list never ends on a half-cut line.
    height: Style.space(24) * 16
    clip: true
    model: procTabRoot.listModel
    spacing: 0
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {
        policy: ScrollBar.AsNeeded
        width: Style.space(6)
        contentItem: Rectangle {
          radius: width / 2
          color: parent.hovered ? panel.foreground : panel.dim
          opacity: parent.size < parent.parent.height ? 0.4 : 0.2
          Behavior on opacity { NumberAnimation { duration: 150 } }
        }
        background: Rectangle {
          color: "transparent"
        }
    }

    delegate: Item {
      id: procRow
      required property var model
      required property int index
      width: procList.width
      height: Style.space(24) + (expanded ? detailBlock.implicitHeight + Style.space(10) : 0)

      readonly property bool current: panel.cursorActive && panel.procIndex === index
      readonly property bool expanded: panel.selectedPid === procRow.model.pid
      readonly property bool paused: procRow.model.state === "T" || procRow.model.state === "t"

      Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      Rectangle {
        anchors.fill: parent
        radius: Style.cornerRadius
        color: procRow.expanded ? Style.selectedFillFor(panel.foreground, Color.accent)
             : (procRow.current ? Style.hoverFillFor(panel.foreground, Color.accent) : "transparent")
        Behavior on color { ColorAnimation { duration: 120 } }
      }

      // ---- the row itself
      Item {
        id: rowLine
        width: parent.width
        height: Style.space(24)

        Text {
          text: procRow.model.name
          textFormat: Text.PlainText
          color: panel.foreground
          font.family: panel.fontFamily
          font.pixelSize: Style.font.bodySmall
          font.bold: procRow.expanded
          elide: Text.ElideRight
          anchors.left: parent.left
          anchors.leftMargin: Style.space(6)
          anchors.right: cellPid.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          id: cellPid
          text: procRow.model.pid
          textFormat: Text.PlainText
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignRight
          width: Style.space(58)
          anchors.right: cellUser.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          id: cellUser
          text: procRow.model.user
          textFormat: Text.PlainText
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.bodySmall
          elide: Text.ElideRight
          width: Style.space(70)
          anchors.right: cellMem.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          id: cellMem
          text: Model.bytesShort(procRow.model.mem)
          textFormat: Text.PlainText
          color: panel.sortKey === "mem" ? panel.foreground : panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignRight
          width: Style.space(58)
          anchors.right: cellCpu.left
          anchors.rightMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
        }
        Text {
          id: cellCpu
          text: Model.percent(procRow.model.cpu, 1)
          textFormat: Text.PlainText
          color: panel.sortKey === "cpu" ? panel.foreground : panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.bodySmall
          horizontalAlignment: Text.AlignRight
          width: Style.space(58)
          anchors.right: parent.right
          anchors.rightMargin: Style.space(6)
          anchors.verticalCenter: parent.verticalCenter
        }

        MouseArea {
          id: rowHover
          anchors.fill: parent
          hoverEnabled: true
          acceptedButtons: Qt.LeftButton
          cursorShape: Qt.PointingHandCursor
          onPositionChanged: { panel.cursorActive = true; panel.cursorFromKeys = false; panel.procIndex = procRow.index }
          onClicked: {
            panel.cursorActive = true
            panel.cursorFromKeys = false
            panel.procIndex = procRow.index
            panel.toggleSelected(procRow.model.pid)
          }
        }

        PanelToolTip {
          visible: rowHover.containsMouse && !procRow.expanded && procRow.model.cmd !== ""
          text: procRow.model.cmd
          fontFamily: panel.fontFamily
        }
      }

      // ---- detail card: full command · facts · actions
      Column {
        id: detailBlock
        visible: procRow.expanded
        anchors.top: rowLine.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Style.space(6)
        anchors.rightMargin: Style.space(6)
        spacing: Style.space(6)

        Text {
          width: parent.width
          text: procRow.model.cmd !== "" ? procRow.model.cmd : "(kernel thread)"
          textFormat: Text.PlainText
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
          wrapMode: Text.WrapAnywhere
          maximumLineCount: 3
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: "PID " + procRow.model.pid + "  ·  parent " + procRow.model.ppid + "  ·  " + procRow.model.threads
            + (procRow.model.threads === 1 ? " thread" : " threads") + "  ·  " + Model.bytes(procRow.model.mem)
            + (procRow.paused ? "  ·  paused" : "")
          textFormat: Text.PlainText
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        Row {
          spacing: Style.space(6)
          topPadding: Style.space(2)

          ActionPill { text: "Terminate"; tooltipText: "Send SIGTERM — ask it to quit"; onClicked: panel.requestSignal(procRow.model, "TERM") }
          ActionPill { text: "Kill"; tooltipText: "Send SIGKILL — end it immediately"; onClicked: panel.requestSignal(procRow.model, "KILL") }
          ActionPill {
            text: procRow.paused ? "Resume" : "Pause"
            tooltipText: procRow.paused ? "Send SIGCONT" : "Send SIGSTOP — freeze it, resumable"
            onClicked: panel.requestSignal(procRow.model, procRow.paused ? "CONT" : "STOP")
          }
          ActionPill { text: "Close"; tooltipText: "Collapse (Esc)"; onClicked: panel.selectedPid = -1 }
        }
      }
    }
  }
}
