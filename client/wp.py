# -*- coding: utf-8 -*-
"""
BridyMee - Native WhatsApp Client for Nokia N9 (MeeGo 1.2 Harmattan)
Version: 1.0.0
Author: Serhat Zahman & Community
"""
import sys
import os
import urllib
import urllib2
import json
import threading
from PySide import QtCore, QtGui, QtDeclarative

# Ensure working directory is set to the application directory
APP_DIR = os.path.dirname(os.path.abspath(__file__))
if not APP_DIR:
    APP_DIR = "/home/user/apps/wp"
os.chdir(APP_DIR)

# Bridge server address (Default: local or companion phone on local Wi-Fi)
# Change this IP to your Bridge Server (e.g. Android Termux or Linux Host)
SERVER_URL = "http://192.168.8.239:8082"

class PyBridge(QtCore.QObject):
    def __init__(self):
        QtCore.QObject.__init__(self)

    @QtCore.Slot(result=unicode)
    def get_chats(self):
        try:
            req = urllib2.urlopen(SERVER_URL + "/chats", timeout=4)
            return req.read().decode('utf-8', 'replace')
        except Exception as e:
            return u"[]"

    @QtCore.Slot(unicode, result=unicode)
    def get_messages(self, jid):
        try:
            url = SERVER_URL + "/messages?jid=" + urllib.quote(jid.encode('utf-8'))
            req = urllib2.urlopen(url, timeout=4)
            return req.read().decode('utf-8', 'replace')
        except Exception as e:
            return u"[]"

    @QtCore.Slot(unicode, unicode)
    def send_message(self, jid, text):
        def async_send():
            try:
                payload = json.dumps({"to": str(jid), "message": text.encode('utf-8')})
                req = urllib2.Request(
                    SERVER_URL + "/send",
                    data=payload,
                    headers={'Content-Type': 'application/json'}
                )
                urllib2.urlopen(req, timeout=5)
            except Exception as e:
                pass
        t = threading.Thread(target=async_send)
        t.daemon = True
        t.start()

def main():
    app = QtGui.QApplication(sys.argv)
    app.setApplicationName("BridyMee")
    app.setOrganizationName("BridyMee")

    view = QtDeclarative.QDeclarativeView()
    bridge = PyBridge()

    view.rootContext().setContextProperty("pyBridge", bridge)
    qml_path = os.path.join(APP_DIR, "main.qml")
    view.setSource(QtCore.QUrl.fromLocalFile(qml_path))
    view.showFullScreen()

    sys.exit(app.exec_())

if __name__ == '__main__':
    main()
