#!/usr/bin/env bash

# Author:   Zhang Huangbin (zhb _at_ iredmail.org)

#---------------------------------------------------------------------
# This file is part of iRedMail, which is an open source mail server
# solution for Red Hat(R) Enterprise Linux, CentOS, Debian and Ubuntu.
#
# iRedMail is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# iRedMail is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with iRedMail.  If not, see <http://www.gnu.org/licenses/>.
#---------------------------------------------------------------------

# -------------------------------------------------------
# ------------------ mlmmj & mlmmj-admin ----------------
# -------------------------------------------------------

mlmmj_config()
{
    ECHO_INFO "Configure mlmmj (mailing list manager)."

    ECHO_DEBUG "Generate script: ${CMD_MLMMJ_AMIME_RECEIVE}."
    cp -f ${SAMPLE_DIR}/mlmmj/mlmmj-amime-receive ${CMD_MLMMJ_AMIME_RECEIVE}
    chown ${MLMMJ_USER_NAME}:${MLMMJ_GROUP_NAME} ${CMD_MLMMJ_AMIME_RECEIVE}
    chmod 0550 ${CMD_MLMMJ_AMIME_RECEIVE}

    perl -pi -e 's#PH_CMD_MLMMJ_RECEIVE#$ENV{CMD_MLMMJ_RECEIVE}#g' ${CMD_MLMMJ_AMIME_RECEIVE}
    perl -pi -e 's#PH_CMD_ALTERMIME#$ENV{CMD_ALTERMIME}#g' ${CMD_MLMMJ_AMIME_RECEIVE}

    ECHO_DEBUG "Create required directories: ${MLMMJ_SPOOL_DIR}, ${MLMMJ_ARCHIVE_DIR}."
    mkdir -p ${MLMMJ_SPOOL_DIR} ${MLMMJ_ARCHIVE_DIR}
    chown ${MLMMJ_USER_NAME}:${MLMMJ_GROUP_NAME} ${MLMMJ_SPOOL_DIR} ${MLMMJ_ARCHIVE_DIR}
    chmod 0700 ${MLMMJ_SPOOL_DIR} ${MLMMJ_ARCHIVE_DIR}

    ECHO_DEBUG "Setting cron job for mlmmj maintenance."
    cat >> ${CRON_FILE_MLMMJ} <<EOF
${CONF_MSG}
# mlmmj: mailing list maintenance
10   */2   *   *   *   find ${MLMMJ_SPOOL_DIR} -mindepth 1 -maxdepth 1 -type d -exec ${CMD_MLMMJ_MAINTD} -F -d {} \\;

EOF

    ECHO_DEBUG "Enable mlmmj transport in postfix: ${POSTFIX_FILE_MAIN_CF}."
    cat ${SAMPLE_DIR}/postfix/main.cf.mlmmj >> ${POSTFIX_FILE_MAIN_CF}

    echo 'export status_mlmmj_config="DONE"' >> ${STATUS_FILE}
}

mlmmj_admin_config()
{
    ECHO_DEBUG "Configure mlmmj-admin (RESTful API server used to manage mlmmj)."

    # Extract source tarball.
    cd ${PKG_MISC_DIR}
    [ -d ${MLMMJ_ADMIN_PARENT_DIR} ] || mkdir -p ${MLMMJ_ADMIN_PARENT_DIR}
    extract_pkg ${MLMMJ_ADMIN_TARBALL} ${MLMMJ_ADMIN_PARENT_DIR}

    # Set file permission.
    chown -R ${MLMMJ_USER_NAME}:${MLMMJ_GROUP_NAME} ${MLMMJ_ADMIN_ROOT_DIR}
    chmod -R 0500 ${MLMMJ_ADMIN_ROOT_DIR}

    # Create symbol link.
    ln -s ${MLMMJ_ADMIN_ROOT_DIR} ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK} >> ${INSTALL_LOG} 2>&1

    # Generate main config file
    cp ${SAMPLE_DIR}/mlmmj/mlmmj-admin.settings.py ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_BIND_HOST#$ENV{MLMMJ_ADMIN_BIND_HOST}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_LISTEN_PORT#$ENV{MLMMJ_ADMIN_LISTEN_PORT}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_USER_NAME#$ENV{MLMMJ_USER_NAME}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_GROUP_NAME#$ENV{MLMMJ_GROUP_NAME}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_PID_FILE#$ENV{MLMMJ_ADMIN_PID_FILE}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_API_AUTH_TOKEN#$ENV{MLMMJ_ADMIN_API_AUTH_TOKEN}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_SPOOL_DIR#$ENV{MLMMJ_SPOOL_DIR}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_ARCHIVE_DIR#$ENV{MLMMJ_ARCHIVE_DIR}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_MLMMJ_SKEL_DIR#$ENV{MLMMJ_SKEL_DIR}#g' ${MLMMJ_ADMIN_CONF}
    perl -pi -e 's#PH_AMAVISD_MLMMJ_PORT#$ENV{AMAVISD_MLMMJ_PORT}#g' ${MLMMJ_ADMIN_CONF}

    perl -pi -e 's#^(backend_api =)(.*)#${1} "bk_none"#g' ${MLMMJ_ADMIN_CONF}

    if [ X"${BACKEND}" == X'OPENLDAP' ]; then
        perl -pi -e 's#^(backend_cli =)(.*)#${1} "bk_iredmail_ldap"#g' ${MLMMJ_ADMIN_CONF}

        cat >> ${MLMMJ_ADMIN_CONF} <<EOF
# LDAP server info. Required by backend 'bk_iredmail_ldap'.
iredmail_ldap_uri = 'ldap://${LDAP_SERVER_HOST}:${LDAP_SERVER_PORT}'
iredmail_ldap_basedn = '${LDAP_BASEDN}'
iredmail_ldap_bind_dn = '${LDAP_ADMIN_DN}'
iredmail_ldap_bind_password = '${LDAP_ADMIN_PW}'
EOF
    elif [ X"${BACKEND}" == X'MYSQL' -o X"${BACKEND}" == X'PGSQL' ]; then
        perl -pi -e 's#^(backend_cli =)(.*)#${1} "bk_iredmail_sql"#g' ${MLMMJ_ADMIN_CONF}

        cat >> ${MLMMJ_ADMIN_CONF} <<EOF
# SQL database which stores meta data of mailing list accounts.
# Required by backend 'bk_iredmail_sql'.
EOF


        if [ X"${BACKEND}" == X'MYSQL' ]; then
            echo 'iredmail_sql_db_type = "mysql"' >> ${MLMMJ_ADMIN_CONF}
        elif [ X"${BACKEND}" == X'PGSQL' ]; then
            echo 'iredmail_sql_db_type = "pgsql"' >> ${MLMMJ_ADMIN_CONF}
        fi

        cat >> ${MLMMJ_ADMIN_CONF} <<EOF
iredmail_sql_db_server = '${SQL_SERVER_ADDRESS}'
iredmail_sql_db_port = ${SQL_SERVER_PORT}
iredmail_sql_db_name = '${VMAIL_DB_NAME}'
iredmail_sql_db_user = '${VMAIL_DB_ADMIN_USER}'
iredmail_sql_db_password = '${VMAIL_DB_ADMIN_PASSWD}'
EOF
    fi

    # Create log directory and empty log file
    mkdir -p ${MLMMJ_ADMIN_LOG_DIR}
    touch ${MLMMJ_ADMIN_LOG_FILE}
    chown ${SYSLOG_DAEMON_USER}:${SYSLOG_DAEMON_GROUP} ${MLMMJ_ADMIN_LOG_DIR} ${MLMMJ_ADMIN_LOG_FILE}

    ECHO_DEBUG "Setting logrotate for dovecot log file."
    if [ X"${KERNEL_NAME}" == X'LINUX' ]; then
        cp -f ${SAMPLE_DIR}/logrotate/mlmmjadmin ${MLMMJ_ADMIN_LOGROTATE_FILE}
        chmod 0644 ${MLMMJ_ADMIN_LOGROTATE_FILE}

        perl -pi -e 's#PH_MLMMJ_ADMIN_LOG_DIR#$ENV{MLMMJ_ADMIN_LOG_DIR}#g' ${MLMMJ_ADMIN_LOGROTATE_FILE}
        perl -pi -e 's#PH_SYSLOG_POSTROTATE_CMD#$ENV{SYSLOG_POSTROTATE_CMD}#g' ${MLMMJ_ADMIN_LOGROTATE_FILE}
    elif [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
        cp -f ${SAMPLE_DIR}/freebsd/newsyslog.conf.d/uwsgi-mlmmjadmin ${MLMMJ_ADMIN_LOGROTATE_FILE}

        perl -pi -e 's#PH_MLMMJ_ADMIN_LOG_FILE#$ENV{MLMMJ_ADMIN_LOG_FILE}#g' ${MLMMJ_ADMIN_LOGROTATE_FILE}
        perl -pi -e 's#PH_MLMMJ_ADMIN_UWSGI_PID_FILE#$ENV{MLMMJ_ADMIN_UWSGI_PID_FILE}#g' ${MLMMJ_ADMIN_LOGROTATE_FILE}

    elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
        if ! grep "${MLMMJ_ADMIN_LOG_FILE}" /etc/newsyslog.conf &>/dev/null; then
            cat >> /etc/newsyslog.conf <<EOF
${MLMMJ_ADMIN_LOG_FILE}    ${MLMMJ_USER_NAME}:${MLMMJ_GROUP_NAME}   600  7     *    24    Z
EOF
        fi
    fi

    ECHO_DEBUG "Generate modular syslog config file for mlmmj-admin."
    if [ X"${USE_RSYSLOG}" == X'YES' ]; then
        # Use rsyslog.
        # Copy rsyslog config file used to filter Dovecot log
        cp ${SAMPLE_DIR}/rsyslog.d/1-iredmail-mlmmj-admin.conf ${SYSLOG_CONF_DIR}

        perl -pi -e 's#PH_IREDMAIL_SYSLOG_FACILITY#$ENV{IREDMAIL_SYSLOG_FACILITY}#g' ${SYSLOG_CONF_DIR}/1-iredmail-mlmmj-admin.conf
        perl -pi -e 's#PH_MLMMJ_ADMIN_LOG_FILE#$ENV{MLMMJ_ADMIN_LOG_FILE}#g' ${SYSLOG_CONF_DIR}/1-iredmail-mlmmj-admin.conf
    elif [ X"${USE_BSD_SYSLOG}" == X'YES' ]; then
        # Log to a dedicated file
        if [ X"${KERNEL_NAME}" == X'FREEBSD' ]; then
            if ! grep "${MLMMJ_ADMIN_LOG_FILE}" ${SYSLOG_CONF} &>/dev/null; then
                echo '' >> ${SYSLOG_CONF}
                echo '!mlmmj-admin' >> ${SYSLOG_CONF}
                echo "${IREDMAIL_SYSLOG_FACILITY}.*        -${MLMMJ_ADMIN_LOG_FILE}" >> ${SYSLOG_CONF}
            fi
        elif [ X"${KERNEL_NAME}" == X'OPENBSD' ]; then
            if ! grep "${MLMMJ_ADMIN_LOG_FILE}" ${SYSLOG_CONF} &>/dev/null; then
                # '!!' means abort further evaluation after first match
                echo '' >> ${SYSLOG_CONF}
                echo '!!mlmmj-admin' >> ${SYSLOG_CONF}
                echo "${IREDMAIL_SYSLOG_FACILITY}.*        -${MLMMJ_ADMIN_LOG_FILE}" >> ${SYSLOG_CONF}
            fi
        fi
    fi

    backup_file ${MLMMJ_ADMIN_UWSGI_CONF}
    cp -f ${SAMPLE_DIR}/uwsgi/mlmmjadmin.ini ${MLMMJ_ADMIN_UWSGI_CONF}

    perl -pi -e 's#PH_IREDMAIL_SYSLOG_FACILITY#$ENV{IREDMAIL_SYSLOG_FACILITY}#g' ${MLMMJ_ADMIN_UWSGI_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_LOG_FILE#$ENV{MLMMJ_ADMIN_LOG_FILE}#g' ${MLMMJ_ADMIN_UWSGI_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_BIND_HOST#$ENV{MLMMJ_ADMIN_BIND_HOST}#g' ${MLMMJ_ADMIN_UWSGI_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_LISTEN_PORT#$ENV{MLMMJ_ADMIN_LISTEN_PORT}#g' ${MLMMJ_ADMIN_UWSGI_CONF}
    perl -pi -e 's#PH_MLMMJ_USER_NAME#$ENV{MLMMJ_USER_NAME}#g' ${MLMMJ_ADMIN_UWSGI_CONF}
    perl -pi -e 's#PH_MLMMJ_GROUP_NAME#$ENV{MLMMJ_GROUP_NAME}#g' ${MLMMJ_ADMIN_UWSGI_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK#$ENV{MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK}#g' ${MLMMJ_ADMIN_UWSGI_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_PID_FILE#$ENV{MLMMJ_ADMIN_PID_FILE}#g' ${MLMMJ_ADMIN_UWSGI_CONF}
    perl -pi -e 's#PH_MLMMJ_ADMIN_UWSGI_PID_FILE#$ENV{MLMMJ_ADMIN_UWSGI_PID_FILE}#g' ${MLMMJ_ADMIN_UWSGI_CONF}

    if [ X"${DISTRO}" == X'RHEL' ]; then
        perl -pi -e 's/^#(plugins.*)/${1}/' ${MLMMJ_ADMIN_UWSGI_CONF}
    elif [ X"${DISTRO}" == X'DEBIAN' -o X"${DISTRO}" == X'UBUNTU' ]; then
        perl -pi -e 's/^#(plugins.*)/${1}/' ${MLMMJ_ADMIN_UWSGI_CONF}
        perl -pi -e 's#^(pidfile =).*#${1} $ENV{MLMMJ_ADMIN_UWSGI_PID_FILE}#g' ${MLMMJ_ADMIN_UWSGI_CONF}
        ln -s ${MLMMJ_ADMIN_UWSGI_CONF} /etc/uwsgi/apps-enabled/$(basename ${MLMMJ_ADMIN_UWSGI_CONF})

    elif [ X"${DISTRO}" == X'FREEBSD' ]; then
        service_control enable 'mlmmjadmin_enable' 'YES' >> ${INSTALL_LOG} 2>&1
        service_control enable 'uwsgi_mlmmjadmin_flags' "--ini ${MLMMJ_ADMIN_UWSGI_CONF} --log-syslog"

        # Rotate log file with newsyslog
        cp -f ${SAMPLE_DIR}/freebsd/newsyslog.conf.d/uwsgi-mlmmjadmin ${MLMMJ_ADMIN_LOGROTATE_FILE}
        perl -pi -e 's#PH_IREDADMIN_UWSGI_PID#$ENV{IREDADMIN_UWSGI_PID}#g' ${MLMMJ_ADMIN_LOGROTATE_FILE}

    elif [ X"${DISTRO}" == X'OPENBSD' ]; then
        cp ${MLMMJ_ADMIN_ROOT_DIR_SYMBOL_LINK}/rc_scripts/mlmmjadmin.openbsd ${DIR_RC_SCRIPTS}/mlmmjadmin >> ${INSTALL_LOG} 2>&1
        rcctl enable mlmmjadmin
        rcctl set mlmmjadmin flags "--ini ${MLMMJ_ADMIN_UWSGI_CONF} --log-syslog" >> ${INSTALL_LOG} 2>&1
        chmod 0755 ${DIR_RC_SCRIPTS}/mlmmjadmin >> ${INSTALL_LOG} 2>&1
    fi

    echo 'export status_mlmmj_admin_config="DONE"' >> ${STATUS_FILE}
}
