# -*- coding: utf-8 -*-
"""
/***************************************************************************
 TOMsMessageLog

                              -------------------
        begin                : 2017-01-01
        git sha              : $Format:%H$
        copyright            : (C) 2017 by TH
        email                : th@mhtc.co.uk
 ***************************************************************************/

/***************************************************************************
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 ***************************************************************************/
"""
import time, datetime
import functools
import os
import sys

from qgis.core import (
    Qgis,
    QgsExpressionContextUtils,
    QgsMessageLog,
    QgsProject,
    QgsApplication
)

class TOMsMessageLog(QgsMessageLog):

    filename = ''

    def __init__(self):
        super().__init__()

    @staticmethod
    def logMessage(*args, **kwargs):
        # check to see if a logging level has been set
        def currentLoggingLevel():

            currLoggingLevel = int(Qgis.MessageLevel.Info)

            try:
                currLoggingLevel = int(QgsExpressionContextUtils.projectScope(QgsProject.instance()).variable('TOMs_Logging_Level'))
            except Exception as e:
                QgsMessageLog.logMessage("Error in TOMsMessageLog. TOMs_logging_Level not found ... {}".format(e), tag="TOMs Panel")

            return currLoggingLevel

        debug_level = currentLoggingLevel()

        if TOMsMessageLog.filename:
            try:
                messageLevel = int(kwargs.get('level'))
            except Exception as e:
                QgsMessageLog.logMessage("Error in TOMsMessageLog. Level in message not found...{}".format(e), tag="TOMs Panel")
                messageLevel = Qgis.MessageLevel.Info

            #QgsMessageLog.logMessage('{}: messageLevel: {}; debug_level: {}'.format(args[0], messageLevel, debug_level), tag="TOMs panel")

            if messageLevel >= debug_level:
                QgsMessageLog.logMessage(*args, **kwargs, tag="TOMs Panel")
                #TOMsMessageLog.write_log_message(args[0], messageLevel, "TOMs Panel", debug_level)
                with open(TOMsMessageLog.filename, 'a') as logfile:
                    logfile.write(
                        '{dateDetails}[{tag}]: {level} :: {message}\n'.format(dateDetails=time.strftime("%Y%m%d:%H%M%S"),
                                                                              tag='TOMs Panel', level=debug_level, message=args[0]))

    def setLogFile(self):

        def _log_path_from_env_file():
            """
            Read QGIS_LOGFILE_PATH from a local .env file if present.
            """
            try:
                base_dir = os.path.dirname(os.path.dirname(__file__))
                env_path = os.path.join(base_dir, '.env')
                if not os.path.exists(env_path):
                    return None

                with open(env_path, 'r') as f:
                    for line in f:
                        line = line.strip()
                        if not line or line.startswith('#'):
                            continue
                        if line.startswith('QGIS_LOGFILE_PATH'):
                            _, _, value = line.partition('=')
                            value = value.strip().strip('"').strip("'")
                            return value or None
            except Exception as e:
                QgsMessageLog.logMessage(
                    "Error in TOMsMessageLog. Problem reading .env for QGIS_LOGFILE_PATH ... {}".format(e),
                    tag="TOMs Panel"
                )
            return None

        logFilePath = None
        base_dir = os.path.dirname(os.path.dirname(__file__))

        # 1) OS environment variable (e.g. Docker sets QGIS_LOGFILE_PATH to a writable path)
        logFilePath = os.environ.get('QGIS_LOGFILE_PATH')
        if logFilePath and not os.path.isabs(logFilePath):
            logFilePath = os.path.abspath(os.path.join(base_dir, logFilePath))

        # 2) Fallback to .env (so users can configure per-project when env var not set)
        if not logFilePath:
            env_file_path = _log_path_from_env_file()
            if env_file_path:
                if not os.path.isabs(env_file_path):
                    env_file_path = os.path.abspath(os.path.join(base_dir, env_file_path))
                logFilePath = env_file_path

        if logFilePath:
            # Ensure the directory exists (create it if necessary)
            try:
                os.makedirs(logFilePath, exist_ok=True)
            except Exception as e:
                QgsMessageLog.logMessage(
                    "Error in TOMsMessageLog. Could not create log directory {} ... {}".format(logFilePath, e),
                    tag="TOMs Panel"
                )
                logFilePath = None

        if logFilePath:
            QgsMessageLog.logMessage("LogFilePath: " + str(logFilePath), tag="TOMs Panel", level=Qgis.MessageLevel.Info)

            logfile = 'qgis_' + datetime.date.today().strftime("%Y%m%d") + '.log'
            TOMsMessageLog.filename = os.path.join(logFilePath, logfile)
            QgsMessageLog.logMessage("Sorting out log file" + self.filename, tag="TOMs Panel", level=Qgis.MessageLevel.Info)
            #QgsApplication.messageLog().messageReceived.connect(self.write_log_message)
        else:
            QgsMessageLog.logMessage(
                "TOMsMessageLog: log file path not configured; file logging disabled",
                tag="TOMs Panel",
                level=Qgis.MessageLevel.Warning
            )

        """def write_log_message(self, *args, **kwargs):
        with open(TOMsMessageLog.filename, 'a') as logfile:
            logfile.write(
                '{dateDetails}[{tag}]: {level} :: {message}\n'.format(dateDetails=time.strftime("%Y%m%d:%H%M%S"),
                                                                      tag=tag, level=level, message=message))"""