pragma Singleton

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common
import qs.modules.nexus.pages
import qs.modules.nexus.pages.apps
import qs.modules.nexus.pages.audio
import qs.modules.nexus.pages.bluetooth
import qs.modules.nexus.pages.network
import qs.modules.nexus.pages.panels
import qs.modules.nexus.pages.services
import qs.modules.nexus.pages.wallandstyle
import qs.modules.nexus.pages.panels.taskbar

QtObject {
    id: root

    readonly property list<Component> pageComps: [

        Component {

            StackPage {
                Component {
                    WallpaperAndStyle {}
                }
                Component {
                    WallpaperSelect {}
                }
                Component {
                    WallpaperCategory {}
                }
                Component {
                    ColourSelect {}
                }
            }
        },

        Component {

            StackPage {
                Component {
                    NetworkPage {}
                }
                Component {
                    EthernetDetailPage {}
                }
                Component {
                    AddNetworkPage {}
                }
                Component {
                    NetworkDetailPage {}
                }
                Component {
                    AddVpnPage {}
                }
                Component {
                    AllNetworksPage {}
                }
                Component {
                    SavedNetworksPage {}
                }
            }
        },
        Component {

            StackPage {
                Component {
                    BluetoothPage {}
                }
                Component {
                    BtDeviceInfo {}
                }
                Component {
                    BluetoothPairing {}
                }
            }
        },
        Component {

            StackPage {
                Component {
                    AudioPage {}
                }
                Component {
                    AppVolumes {}
                }
            }
        },

        Component {
            PlaceholderComp {}
        },
        Component {
            PlaceholderComp {}
        },

        Component {

            StackPage {
                Component {
                    PanelsPage {}
                }
                Component {
                    DashboardPanel {}
                }
                Component {
                    TaskbarPanel {}
                }
                Component {
                    LauncherPanel {}
                }
                Component {
                    SidebarPanel {}
                }
                Component {
                    UtilitiesPanel {}
                }

                Component {
                    BarWorkspaces {}
                }
                Component {
                    BarActiveWindow {}
                }
                Component {
                    BarTray {}
                }
                Component {
                    BarStatusIcons {}
                }
                Component {
                    BarClock {}
                }
                // Lock screen (caelestia-zeti); appended so taskbar sub-page indices stay 6-10
                Component {
                    LockScreenPanel {}
                }
            }
        },
        Component {

            StackPage {
                Component {
                    AppsPage {}
                }
                Component {
                    AllApps {}
                }
                Component {
                    AppInfo {}
                }
            }
        },
        Component {

            StackPage {
                Component {
                    ServicesPage {}
                }
                Component {
                    NotificationsPage {}
                }
            }
        },
        Component {

            StackPage {
                Component {
                    LanguageAndRegion {}
                }
            }
        },

        Component {
            StackPage {
                Component {
                    AboutPage {}
                }
            }
        }
    ]

    readonly property Component placeholderComp: Component {
        PlaceholderComp {}
    }

    component PlaceholderComp: Item {
        property NexusState nState

        ColumnLayout {
            anchors.centerIn: parent
            spacing: Tokens.padding.extraSmall

            MaterialIcon {
                Layout.alignment: Qt.AlignHCenter
                text: "handyman"
                color: Colours.p(Tokens.screen).m3outlineVariant
                fontStyle: Tokens.font.icon.extraLarge
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("Page under construction")
                color: Colours.p(Tokens.screen).m3outlineVariant
                font: Tokens.font.title.large
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Tr.tr("This page will be available in a future update.")
                color: Colours.p(Tokens.screen).m3outlineVariant
                font: Tokens.font.body.large
            }
        }
    }
}
