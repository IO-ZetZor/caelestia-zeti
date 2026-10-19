pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.components.misc
import qs.services

Scope {
    id: root

    property alias lock: lock

    // WlSessionLock does not emit lockStateChanged when it releases: the
    // compositor's lock is already cleared by the time unlock() checks
    // isLocked(). A binding to lock.locked therefore keeps its last true
    // value, leaving ShellState.locked stuck after unlocking. Mirror the
    // compositor's secure state through a property whose notifies we control.
    property bool lockActive: false

    WlSessionLock {
        id: lock

        signal unlock

        onSecureChanged: root.lockActive = lock.secure

        LockSurface {
            lock: lock
            pam: pam
        }
    }

    Binding {
        target: ShellState
        property: "locked"
        value: root.lockActive
    }

    Pam {
        id: pam

        lock: lock
    }

    Loader {
        asynchronous: true
        active: true
        onLoaded: active = false

        sourceComponent: ScreencopyView {
            captureSource: Quickshell.screens[0]
        }
    }

    CustomShortcut {

        name: "lock"
        description: "Lock the current session"
        onPressed: lock.locked = true
    }

    CustomShortcut {

        name: "unlock"
        description: "Unlock the current session"
        onPressed: lock.unlock()
    }

    IpcHandler {
        function lock(): void {
            lock.locked = true;
        }

        function unlock(): void {
            lock.unlock();
        }

        function isLocked(): bool {
            return lock.locked;
        }

        target: "lock"
    }
}
