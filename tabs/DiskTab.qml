import QtQuick
import QtQuick.Controls
import qs.Commons
import qs.Ui
import "../Model.js" as Model
import "../components"

Column {
  required property var panel

  component DriveHeading: DriveHeadingComponent {
    foreground: panel.foreground
    dim: panel.dim
    fontFamily: panel.fontFamily
  }

  component SectionRow: SectionRowComponent {
    foreground: panel.foreground
    dim: panel.dim
    fontFamily: panel.fontFamily
  }

  component Meter: MeterComponent {
    fillColor: panel.foreground
    trackColor: panel.track
  }

  spacing: Style.space(12)

  PanelSectionHeader {
    text: "DISKS"
    foreground: panel.foreground
    fontFamily: panel.fontFamily
  }

  Text {
    visible: panel.hasData && (panel.snapshot.blockdevs ? panel.snapshot.blockdevs.length : 0) === 0 && panel.disks.length === 0
    text: "No disks detected"
    color: panel.dim
    font.family: panel.fontFamily
    font.pixelSize: Style.font.bodySmall
  }

  Repeater {
    model: panel.snapshot && panel.snapshot.blockdevs ? panel.snapshot.blockdevs : []

    delegate: Column {
      id: driveCard
      required property var modelData
      required property int index
      width: parent.width
      spacing: Style.space(8)

      property bool expanded: false
      readonly property var partitions: {
        var name = modelData.name
        var out = []
        for (var i = 0; i < panel.disks.length; i++) {
          var d = panel.disks[i]
          if (!d || !d.source) continue
          if (d.smart_dev === name
              || d.source === "/dev/" + name
              || d.source.indexOf("/dev/" + name + "p") === 0
              || d.source.indexOf("/dev/" + name + "/") === 0) {
            out.push(d)
          }
        }
        return out
      }
      readonly property bool activeSmart: panel.smartDev === modelData.name

      PanelSeparator { visible: index > 0; foreground: panel.foreground }

      DriveHeading {
        glyphText: modelData.transport === "usb" ? "\uF08EB" : modelData.transport === "nvme" ? "\uF01A0" : "\uF02CA"
        accent: modelData.removable ? "#ffb800" : panel.dim
        title: modelData.model || modelData.name
        meta: Model.bytes(modelData.bytes) + " · " + modelData.transport + (modelData.removable ? " · removable" : "")
      }

      Column {
        width: parent.width
        spacing: Style.space(6)
        visible: driveCard.partitions.length > 0

        Text {
          text: "PARTITIONS"
          color: panel.faint
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
          font.letterSpacing: 1
        }

        Repeater {
          model: driveCard.partitions

          delegate: Column {
            id: partRow

            required property var modelData
            width: parent.width
            spacing: Style.space(4)

            readonly property string partKey: String(modelData.source || "") || String(modelData.mount || "") || String(modelData.label || "")
            readonly property bool isOpen: !!panel.expandedParts[partKey]
            readonly property real fraction: modelData.total > 0 ? modelData.used / modelData.total : 0

            Item {
              width: parent.width
              implicitHeight: Math.max(partName.implicitHeight, partMeta.implicitHeight)

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: panel.togglePart(partRow.partKey)
              }

              Text {
                id: partName
                text: modelData.mount ? Model.mountLabel(modelData.mount) : (String(modelData.source || "").indexOf("/dev/mapper/") === 0 ? "crypt" : (String(modelData.source || "").indexOf("/dev/") === 0 ? String(modelData.source).substring(5) : "disk"))
                color: panel.foreground
                font.family: panel.fontFamily
                font.pixelSize: Style.font.bodySmall
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: partMeta
                text: modelData.fstype || "filesystem"
                color: panel.dim
                font.family: panel.fontFamily
                font.pixelSize: Style.font.caption
                anchors.left: partName.right
                anchors.leftMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: usageMeta
                text: partRow.modelData.total > 0 ? Model.bytes(partRow.modelData.used) + " / " + Model.bytes(partRow.modelData.total) + " · " + Model.percent(partRow.fraction * 100) : "—"
                color: panel.foreground
                font.family: panel.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: chevron.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                visible: !!partRow.modelData.mount
                text: "(" + (partRow.modelData.mount || "") + ")"
                color: panel.dim
                font.family: panel.fontFamily
                font.pixelSize: Style.font.caption
                anchors.right: usageMeta.left
                anchors.rightMargin: Style.space(8)
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: chevron
                text: partRow.isOpen ? "▾" : "›"
                color: panel.dim
                font.family: panel.fontFamily
                font.pixelSize: Style.font.body
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            Meter {
              visible: partRow.modelData.total > 0
              value: partRow.fraction
            }

            Text {
              // Always occupies one line so rows don't shift when IO goes idle
              text: {
                var r = partRow.modelData.read_bps
                var w = partRow.modelData.write_bps
                var hR = r !== null && r !== undefined && r > 0
                var hW = w !== null && w !== undefined && w > 0
                if (hR && hW) return "read " + Model.rate(r) + "  ·  write " + Model.rate(w)
                if (hR) return "read " + Model.rate(r)
                if (hW) return "write " + Model.rate(w)
                return " "
              }
              color: panel.dim
              font.family: panel.fontFamily
              font.pixelSize: Style.font.caption
            }

            Column {
              visible: partRow.isOpen
              width: parent.width
              spacing: Style.space(4)

              SectionRow {
                visible: !!partRow.modelData.source
                label: "Device"
                value: String(partRow.modelData.source || "")
                valueDim: true
              }
            }
          }
        }
      }

      Text {
        visible: driveCard.partitions.length === 0
        text: "NO PARTITIONS"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      Row {
        spacing: Style.space(10)

        Button {
          text: driveCard.activeSmart && panel.smartState === "running" ? "Checking\u2026" : "SMART"
          fontSize: Style.font.caption
          foreground: driveCard.activeSmart ? panel.foreground : panel.dim
          fontFamily: panel.fontFamily
          bordered: true
          horizontalPadding: Style.space(8)
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: {
            if (driveCard.activeSmart) { panel.smartDev = ""; panel.smartState = "" }
            else panel.querySmartDev(modelData.name)
          }
        }

        Text {
          visible: !panel.hasSmart
          anchors.verticalCenter: parent.verticalCenter
          text: "requires smartmontools"
          color: panel.dim
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
        }

        Button {
          visible: !panel.hasSmart
          text: "Install"
          fontSize: Style.font.caption
          foreground: panel.foreground
          fontFamily: panel.fontFamily
          bordered: true
          horizontalPadding: Style.space(8)
          verticalPadding: Style.spacing.controlPaddingY
          onClicked: panel.installSmart()
        }
      }

      Text {
        visible: driveCard.activeSmart && panel.smartState === "running"
        width: parent.width
        text: "Waiting for authorization\u2026"
        color: panel.dim
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      Text {
        visible: driveCard.activeSmart && panel.smartState === "error"
        width: parent.width
        text: "Could not read SMART data (cancelled or unsupported device)"
        color: "#ff9933"
        font.family: panel.fontFamily
        font.pixelSize: Style.font.caption
      }

      Column {
        readonly property var report: driveCard.activeSmart && panel.smartState === "done" && panel.smartOut !== "" ? panel.parseSmart(panel.smartOut) : null
        visible: report !== null
        width: parent.width
        spacing: Style.space(6)

        Text {
          visible: parent.report && parent.report.verdict !== null
          width: parent.width
          text: {
            if (!parent.report || parent.report.verdict === null) return ""
            var extra = ""
            var mm = panel.smartOut.match(/Percentage Used:\s*(\d+)%/)
            if (mm) extra = "  ·  ≈ " + Math.max(0, 100 - parseInt(mm[1])) + "% life left"
            return "Health: " + parent.report.verdict + extra
          }
          color: parent.report && String(parent.report.verdict).indexOf("PASSED") >= 0 ? "#66ff66" : "#ff3333"
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        Repeater {
          model: parent.report ? parent.report.rows : []

          delegate: Row {
            required property int index
            required property var modelData
            width: parent.width
            spacing: Style.space(8)

            Text {
              width: parent.width * 0.55
              text: modelData.k
              color: panel.dim
              font.family: panel.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            Text {
              text: modelData.v
              color: panel.foreground
              font.family: panel.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }
        }

        Text {
          visible: parent.report && parent.report.rows.length === 0
          width: parent.width
          text: parent.report ? parent.report.raw : ""
          color: panel.dim
          opacity: 0.8
          wrapMode: Text.WrapAnywhere
          font.family: panel.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
