import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.mauikit.controls as Maui

Maui.SettingsDialog {
    id: control

    property var appSettings

    Maui.Controls.title: qsTr("Preferences")

    Maui.SectionGroup {
        title: qsTr("General")
        description: qsTr("Configure how AppFinder starts and reports operations.")

        Maui.FlexSectionItem {
            label1.text: qsTr("Refresh sources on startup")
            label2.text: qsTr("Update Flathub, NX AppHub, and Distrobox data when AppFinder opens.")
            label2.wrapMode: Text.WordWrap

            Switch {
                checkable: true
                checked: control.appSettings && control.appSettings.refreshOnStartup
                onToggled: control.appSettings.refreshOnStartup = checked
            }
        }

        Maui.FlexSectionItem {
            label1.text: qsTr("Show sidebar at startup")
            label2.text: qsTr("Keep the source navigation sidebar open when AppFinder starts.")
            label2.wrapMode: Text.WordWrap

            Switch {
                checkable: true
                checked: control.appSettings && control.appSettings.sidebarVisible
                onToggled: control.appSettings.sidebarVisible = checked
            }
        }
    }

    Maui.SectionGroup {
        title: qsTr("Flathub")
        description: qsTr("Choose the first view shown in the Flathub catalog.")

        Maui.FlexSectionItem {
            label1.text: qsTr("Start in Installed view")
            label2.text: qsTr("Open the installed applications list instead of the Explore catalog.")
            label2.wrapMode: Text.WordWrap

            Switch {
                checkable: true
                checked: control.appSettings && control.appSettings.startInInstalledView
                onToggled: control.appSettings.startInInstalledView = checked
            }
        }
    }
}
