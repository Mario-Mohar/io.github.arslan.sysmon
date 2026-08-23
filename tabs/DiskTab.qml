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

  Item {
    width: parent.width
    height: panel.mountBusy ? Style.space(4) : 0
    visible: panel.mountBusy

    Rectangle {
      anchors.left: parent.left
      anchors.bottom: parent.bottom
      width: parent.width * 0.6
      height: parent.height
      radius: height / 2
      color: "#ffb800"

      SequentialAnimation on x {
        running: panel.mountBusy
        loops: Animation.Infinite
        NumberAnimation { from: -parent.parent.width * 0.6; to: parent.parent.width; duration: 1200; easing.type: Easing.InOutQuad }
      }
    }
  }

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

  Text {
    visible: panel.mountErr !== ""
    width: parent.width
    text: panel.mountErr
    color: "#ff9933"
    font.family: panel.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WrapAnywhere
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
      property bool showRawKids: false

      function matchPart(d) {
        var name = modelData.name
        var src = String(d.source || "")
        var prefix = "/dev/" + name
        if (d.smart_dev === name) return true
        if (src === prefix) return true
        if (src.indexOf(prefix) === 0) {
          var rest = src.charAt(prefix.length)
          if (rest === "p" || rest === "s" || (rest >= "0" && rest <= "9") || rest === "/") return true
        }
        return false
      }

      function isUnmountable(fstype) {
        var t = String(fstype || "").toLowerCase()
        return t === "" || t === "null" || t === "swap" || t === "linux_raid_member" || t === "bios_boot" || t === "extended"
      }

      readonly property var partitions: panel.disks.filter(function (d) {
        return !!d && !!d.source && driveCard.matchPart(d)
      })

      readonly property var allPartitions: panel.disks.filter(function (d) {
        return !!d && !!d.source && driveCard.matchPart(d)
      })

      readonly property var rawKids: (modelData.children || []).filter(function (c) {
        for (var i = 0; i < allPartitions.length; i++) {
          var src = allPartitions[i] ? String(allPartitions[i].source || "") : ""
          if (src === "/dev/" + c.name) return false
        }
        return !c.mountpoint
      })

      readonly property int hiddenCount: rawKids.length
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

        Item {
          width: parent.width
          implicitHeight: partsHdr.implicitHeight

          Text {
            id: partsHdr
            text: "PARTITIONS"
            color: panel.faint
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
            font.bold: true
            font.letterSpacing: 1
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
          }

          Text {
            id: partsMore
            text: driveCard.showRawKids ? "less ▴" : "+" + driveCard.hiddenCount + " unmounted"
            visible: driveCard.showRawKids || driveCard.hiddenCount !== 0
            color: "#ffb800"
            font.bold: true
            font.family: panel.fontFamily
            font.pixelSize: Style.font.caption
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: driveCard.showRawKids = !driveCard.showRawKids
            }
          }
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

              SectionRow {
                visible: !!partRow.modelData.mount
                label: "Mount"
                value: String(partRow.modelData.mount || "")
                valueDim: true
              }

              Item {
                width: parent.width
                height: unmountBtn.height + Style.space(8)

                Button {
                  id: unmountBtn
                  anchors.left: parent.left
                  anchors.verticalCenter: parent.verticalCenter
                  visible: !!partRow.modelData.mount && partRow.modelData.mount !== "/"
                  text: panel.mountBusy ? "…" : "UNMOUNT"
                  fontSize: Style.font.caption
                  foreground: "#ff6666"
                  fontFamily: panel.fontFamily
                  bordered: true
                  horizontalPadding: Style.space(8)
                  verticalPadding: Style.spacing.controlHeight * 0.14
                  onClicked: panel.unmountDevice(partRow.modelData.source)
                }
              }
            }
          }
        }
      }

      Repeater {
        model: driveCard.showRawKids ? driveCard.rawKids : []

        delegate: Column {
          required property var modelData
          width: parent.width
          spacing: Style.space(2)

          Item {
            width: parent.width
              implicitHeight: Math.max(childName.implicitHeight, childMeta.implicitHeight, mountBtn.visible ? mountBtn.implicitHeight : 0, unmountBtn.visible ? unmountBtn.implicitHeight : 0, mountInput.visible ? mountInput.implicitHeight : 0)

            Text {
              id: childName
              text: String(modelData.name || "")
              color: panel.foreground
              font.family: panel.fontFamily
              font.pixelSize: Style.font.bodySmall
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Text {
              id: childMeta
              text: {
                var fs = String(modelData.fstype || "")
                var fsLabel = fs === "" || fs === "null" ? "no filesystem" : fs
                var size = Model.bytes(modelData.bytes || 0)
                var mount = modelData.mountpoint ? " (" + modelData.mountpoint + ")" : " (unmounted)"
                return fsLabel + " · " + size + mount
              }
              color: modelData.mountpoint ? panel.dim : (modelData.fstype ? "#ffb800" : panel.dim)
              font.family: panel.fontFamily
              font.pixelSize: Style.font.caption
              anchors.right: mountInput.visible ? mountInput.left : (unmountBtn.visible ? unmountBtn.left : (mountBtn.visible ? mountBtn.left : parent.right))
              anchors.rightMargin: Style.space(8)
              anchors.verticalCenter: parent.verticalCenter
            }

            TextField {
              id: mountInput
              visible: false
              anchors.right: mountBtn.visible ? mountBtn.left : parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(120)
              height: Style.space(32)
              placeholderText: "/mnt/data"
              font.family: panel.fontFamily
              font.pixelSize: Style.font.caption
              verticalAlignment: TextInput.AlignVCenter
              color: panel.foreground
              background: Rectangle {
                radius: Style.space(4)
                color: panel.track
                border.color: panel.foreground
                border.width: 1
              }
              onAccepted: {
                var path = mountInput.text.trim()
                if (path === "") {
                  panel.mountDevice("/dev/" + modelData.name)
                } else if (path.indexOf("/") !== 0) {
                  panel.mountErr = "Path must start with /"
                  return
                } else if (path === "/" || path === "/home" || path === "/root" || path === "/etc" || path === "/var" || path === "/usr" || path === "/bin" || path === "/sbin" || path === "/lib" || path === "/dev" || path === "/proc" || path === "/sys" || path === "/boot" || path === "/boot/efi" || path === "/efi" || path === "/efi/boot") {
                  panel.mountErr = "Cannot mount at system path: " + path
                  return
                } else if (path.indexOf(" ") !== -1) {
                  panel.mountErr = "Path cannot contain spaces"
                  return
                } else {
                  // Check if path is already a mount point
                  var disks = panel.disks || []
                  for (var i = 0; i < disks.length; i++) {
                    if (disks[i] && disks[i].mount === path) {
                      panel.mountErr = "Already mounted at " + path
                      return
                    }
                  }
                  panel.mountDevice("/dev/" + modelData.name, path)
                }
                mountInput.visible = false
                mountInput.text = ""
              }
              onVisibleChanged: if (visible) forceActiveFocus()
            }

            Button {
              id: unmountBtn
              anchors.right: mountBtn.visible ? mountBtn.left : parent.right
              anchors.rightMargin: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              visible: !!modelData.mountpoint && modelData.mountpoint !== "/"
              text: panel.mountBusy ? "…" : "UNMOUNT"
              fontSize: Style.font.caption
              foreground: "#ff6666"
              fontFamily: panel.fontFamily
              bordered: true
              horizontalPadding: Style.space(8)
              verticalPadding: Style.spacing.controlHeight * 0.14
              onClicked: panel.unmountDevice("/dev/" + modelData.name)
            }

            Button {
              id: mountBtn
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              visible: !modelData.mountpoint && !driveCard.isUnmountable(modelData.fstype)
              text: panel.mountBusy ? "…" : "MOUNT"
              fontSize: Style.font.caption
              foreground: panel.foreground
              fontFamily: panel.fontFamily
              bordered: true
              horizontalPadding: Style.space(8)
              verticalPadding: Style.spacing.controlPaddingY
              onClicked: {
                driveCard.showRawKids = true
                if (mountInput.visible) {
                  panel.mountDevice("/dev/" + modelData.name)
                  mountInput.visible = false
                  mountInput.text = ""
                } else {
                  mountInput.visible = true
                  mountInput.forceActiveFocus()
                }
              }
            }
          }
        }
      }

      Text {
        visible: driveCard.partitions.length === 0 && !(modelData.children && modelData.children.length !== 0)
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
