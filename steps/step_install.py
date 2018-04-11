import time
import os
import logging
import re
import commands
from behave import *
from hamcrest import *

from lib.nodes import get_node, get_ssh, get_sftp

LOGGER = logging.getLogger('steps.install')

@Given('a clean environment in all dble nodes')
def clean_dble_in_all_nodes(context):
    for node in context.dbles:
        uninstall_dble_by_ip(context, node.ip)

@When('uninstall dble by "{ip}" ')
def uninstall_dble_by_ip(context, ip):
    ssh_client = get_ssh(context.dbles, ip)
    cmd_status = "ps aux|grep dble|grep 'start'| grep -v grep | awk '{print $2}'"
    rc, sto, ste = ssh_client.exec_command(cmd_status)
    if len(sto) == 0:
        LOGGER.info("dble status is stopped!!!")
    else:
        LOGGER.info("try to stop dble server")
        cmd = "cd {0} && (./dble/bin/dble stop)".format(context.dble_test_config['dble_basepath'])
        ssh_client.exec_command(cmd)
        rc, sto, ste = ssh_client.exec_command(cmd_status)
        if len(sto) == 0:
            LOGGER.info("stop dble successed")
        else:
            cmd = "kill {0} {1}".format(sto[0], sto[1])
            ssh_client.exec_command(cmd)
            rc, sto, ste = ssh_client.exec_command(cmd_status)
            if len(sto) == 0:
                LOGGER.info("kill dble successed")
            else:
                assert_that(False, "stop dble fialure")

    cmd = "cd {0} && rm -rf {1}".format(context.dble_test_config['dble_basepath'], "dble")
    ssh_client.exec_command(cmd)
    zknode = check_zk_node_exists(context)
    if zknode:
        check_and_clear_zk(context)

@given('uninstall dble in "{hostname}"')
def unistall_dble_by_hostname(context, hostname):
    node = get_node(context.dbles, hostname)
    uninstall_dble_by_ip(context, node.ip)

def install_dble_by_ip(context, ip):
    ssh_client = get_ssh(context.dbles, ip)
    dble_packget = ""
    if context.need_download == False:
        dble_packget = "{0}".format(context.dble_test_config['dble']['local_packget'])
    else:
        context.execute_steps(u'Given download dble')
        dble_packget = "{0}".format(context.dble_test_config['dble']['remote_packget'])
    cmd = "cd {0} && sudo rm -rf {1}".format(context.dble_test_config['dble_basepath'], dble_packget)
    ssh_client.exec_command(cmd)
    cmd = "cd {0} && sudo cp -r {1} {2}".format(context.dble_test_config['share_path_docker'], dble_packget,
                                           context.dble_test_config['dble_basepath'])
    ssh_client.exec_command(cmd)
    cmd = "cd {0} && tar xf {1}".format(context.dble_test_config['dble_basepath'], dble_packget)
    ssh_client.exec_command(cmd)

@Given('install dble in "{hostname}"')
def install_dble_in_host(context, hostname):
    install_dble_by_ip(context, hostname)
    replace_config(context, context.dble_test_config['dble_base_conf'], hostname)

@Given('install dble in all dble nodes')
def install_dble_in_all_nodes(context):
    for node in context.dbles:
        install_dble_in_host(context, node.ip)

@Then('Start dble in "{hostname}"')
def start_dble_in_hostname(context, hostname):
    ssh_client = get_ssh(context.dbles, hostname)
    cmd = "cd {0} && (./dble/bin/dble start)".format(context.dble_test_config['dble_basepath'])
    ssh_client.exec_command(cmd)
    context.retry = 0
    check_dble_started(context, ssh_client)

def check_dble_started(context, ssh_client):
    time.sleep(5)
    cmd = "ps aux|grep dble|grep 'start'| grep -v grep | awk '{print $2}'"
    rc, sto, ste = ssh_client.exec_command(cmd)
    LOGGER.info("rc: {0}, sto: {1}, ste: {2}".format(rc, sto, ste))
    if len(sto) == 0:
        if context.retry < 5:
            context.retry = context.retry+1
            check_dble_started(context, ssh_client)
        else:
            assert_that(False, "start dble service fail in 25 seconds!")
    else:
        LOGGER.info("start dble success !!!")

@Then('stop dble in "{hostname}"')
def stop_dble_in_hostname(context, hostname):
    ssh_client = get_ssh(context.dbles, hostname)
    cmd = "cd {0} && (./dble/bin/dble stop)".format(context.dble_test_config['dble_basepath'])
    ssh_client.exec_command(cmd)
    time.sleep(3)
    cmd = "ps aux|grep dble|grep 'start'| grep -v grep | awk '{print $2}'"
    rc, sto, re = ssh_client.exec_command(cmd)
    if re.find(" "):
        assert_that(True, "stop dble succeed")
    else:
        assert_that(False, "stop dble service fail !")

@Given('download dble')
def download_dble(context):
    LOGGER.info("delete local dble  packget")
    dir_rpm = "{0}/{1}".format(context.dble_test_config['share_path_agent'],
                               context.dble_test_config['dble']['remote_packget'])
    ftp_url = "{0}{1}".format(context.dble_test_config['dble']['remote_path'],
                              context.dble_test_config['dble']['remote_packget'])
    cmd = 'rm -rf {0}'.format(dir_rpm)
    os.system(cmd)

    cmd = 'cd {0} && wget --user=ftp --password=ftp -nv {1}'.format(context.dble_test_config['share_path_agent'],
                                                                    ftp_url)
    os.popen(cmd)

    cmd = "find {0} -maxdepth 1 -name {1} | wc -l".format(context.dble_test_config['share_path_agent'],
                                                          context.dble_test_config['dble']['remote_packget'])
    str = os.popen(cmd).read()
    assert_that(str.strip(), equal_to('1'), "Download dble tar fail")

@Given('check dble is installed in "{hostname}"')
def check_dble_installed(context, hostname):
    ssh_client = get_ssh(context.dbles, hostname)
    cmd = "sh {0}/dble/bin/dble status".format(context.dble_test_config['dble_basepath'])
    rc, sto, ste = ssh_client.exec_command(cmd)
    if sto.find("dble-server is running") != -1:
        return True
    return False

@Given('Set the log level to "{log_level}" and restart server in "{hostname}"')
def Log_debug(context, log_level, hostname):
    ssh_client = get_ssh(context.dbles, hostname)
    str_awk = "awk 'FS=\" \" {print $2}'"
    cmd = "cat {0}/dble/conf/log4j2.xml | grep -e '<asyncRoot*' | {1} | cut -d= -f2 ".format(context.dble_test_config['dble_basepath'], str_awk)
    rc, sto, ste = ssh_client.exec_command(cmd)
    LOGGER.info("rc: {0}; sto: {1}; ste: {2}".format(rc, sto, ste))
    if log_level in sto:
        pass
    else:
        log = '{0}/dble/conf/log4j2.xml'.format(context.dble_test_config['dble_basepath'])
        cmd = "sed -i 's/{0}/{1}/g' {2} ".format(sto[1:-1], log_level, log)
        ssh_client.exec_command(cmd)
        cmd = "cd {0} && (./dble/bin/dble restart)".format(context.dble_test_config['dble_basepath'])
        ssh_client.exec_command(cmd)
        time.sleep(3)
        check_dble_installed(context, hostname)

@Given('Restart dble in "{hostname}"')
def restart_dble(context, hostname):
    stop_dble_in_hostname(context, hostname)
    start_dble_in_hostname(context, hostname)
    time.sleep(3)
    check_dble_installed(context, hostname)

@Given('Check and clear zookeeper stored data in all dble nodes')
def check_and_clear_zk(context):
    context.zk_retry=0
    for node in context.dbles:
        check_zk_status(context, node.ip)
        clear_zk_data(context, node.ip)

def check_zk_status(context, ip):
    ssh_client = get_ssh(context.dbles, ip)
    cmd = "{0}/bin/zkServer.sh status".format(context.dble_test_config['zookeeper']['home'])
    rc, sto, ste = ssh_client.exec_command(cmd)
    LOGGER.info("rc: {0}, sto: {1}, ste: {2}".format(rc, sto, ste))
    if context.zk_retry < 3 and re.search("Error contacting service", sto, re.I):
        context.zk_retry = context.zk_retry+1
        cmd = "{0}/bin/zkServer.sh start".format(context.dble_test_config['zookeeper']['home'])
        rc, sto, ste = ssh_client.exec_command(cmd)
        check_zk_status(context, ip)
    assert_that(str(sto), contains_string("Mode"))

def clear_zk_data(context, ip):
    ssh_client = get_ssh(context.dbles, ip)
    cmd = "{0}/bin/zkCli.sh rmr /dble".format(context.dble_test_config['zookeeper']['home'])
    ssh_client.exec_command(cmd)
    cmd = "{0}/bin/zkCli.sh ls /dble".format(context.dble_test_config['zookeeper']['home'])
    rc, sto, ste = ssh_client.exec_zk_command(cmd)
    LOGGER.info("rc: {0}, sto: {1}, ste: {2}".format(rc, sto, ste))
    assert_that(ste, contains_string("Node does not exist: /dble"))

@Given('config zookeeper cluster in all dble nodes')
def config_zk_in_dble_nodes(context):
    for node in context.dbles:
        stop_dble_in_hostname(context, node.host_name)
        conf_zk_in_dble_by_hostname(context, node.host_name)
    check_and_clear_zk(context)
    order_start_all_dble(context)

def order_start_all_dble(context):
    start_dble_in_hostname(context, "dble-1")
    for node in context.dbles:
        if "dble-1" not in node.host_name:
            start_dble_in_hostname(context, node.host_name)

def conf_zk_in_dble_by_hostname(context, hostname):
    ssh_client = get_ssh(context.dbles, hostname)
    conf_file = "{0}/dble/conf/myid.properties".format(context.dble_test_config['dble_basepath'])
    cmd = "cat {0} | grep 'loadZK*'|cut -d= -f2".format(conf_file)
    rc, sto, ste = ssh_client.exec_command(cmd)
    LOGGER.info("rc: {0}, sto: {1}, ste: {2}".format(rc, sto, ste))
    assert_that(ste, is_(""))
    if "false" in sto :
        cmd = "sed -i 's/false/true/g' {0}".format(conf_file)
        rc, sto, ste = ssh_client.exec_command(cmd)
        LOGGER.info("rc: {0}, sto: {1}, ste: {2}".format(rc, sto, ste))
        assert_that(ste, is_(""))
        cmd = "sed -i '/^myid/d' {0}".format(conf_file)
        rc, sto, ste = ssh_client.exec_command(cmd)
        assert_that(ste, is_(""))
        cmd = " "
        if "1" in hostname:
            cmd = "sed -i '$a myid=1' {0}".format(conf_file)
        elif "2" in hostname:
            cmd = "sed -i '$a myid=2' {0}".format(conf_file)
        else:
            cmd = "sed -i '$a myid=3' {0}".format(conf_file)
        rc, sto, ste = ssh_client.exec_command(cmd)
        assert_that(ste, is_(""))

@given('Restore and ensure that all dble nodes are not cluster-mode')
def restore_and_ensure_dble_uncluster(context):
    zknode = check_zk_node_exists(context)
    if zknode:
        conf_file = "{0}/dble/conf/myid.properties".format(context.dble_test_config['dble_basepath'])
        cmd = "cat {0} | grep 'loadZK*' | cut -d= -f2".format(conf_file)
        for node in context.dbles:
            stop_dble_in_hostname(context, node.host_name)
            ssh_client = node.sshconn
            rc, sto, ste = ssh_client.exec_command(cmd)
            LOGGER.info("rc: {0}, sto: {1}, ste: {2}".format(rc, sto, ste))
            assert_that(ste, is_(""))
            if "true" in sto:
                cmd = "sed -i 's/true/false/g' {0}".format(conf_file)
                rc, sto, ste = ssh_client.exec_command(cmd)
                LOGGER.info("rc: {0}, sto: {1}, ste: {2}".format(rc, sto, ste))
                assert_that(ste, is_(""))
                LOGGER.info("config dble node: {0} myid.properties is false".format(node.host_name))
        LOGGER.info("Start only the Dble service on the node {0}".format("dble-1"))
        check_and_clear_zk(context)
    start_dble_in_hostname(context, "dble-1")

def check_zk_node_exists(context):
    cmd = "{0}/bin/zkCli.sh ls /dble".format(context.dble_test_config['zookeeper']['home'])
    for node in context.dbles:
        ssh_client = node.sshconn
        rc, sto, ste = ssh_client.exec_zk_command(cmd)
        LOGGER.info("rc: {0}, sto: {1}, ste: {2}".format(rc, sto, ste))
        if "Node does not exist: /dble" not in sto:
            return True
    return False

def check_dble_status(context, hostname):
    ssh_client = get_ssh(context.dbles, hostname)
    cmd = "cd {0} && (./dble/bin/dble status)".format(context.dble_test_config['dble_basepath'])
    rc, sto, ste = ssh_client.exec_command(cmd)
    if sto.find("dble-server is running"):
        return True
    return False

@Given('Replace the existing configuration with the conf template directory')
def replace_config(context, sourceCfgDir, dest=None):
    LOGGER.info("sour config dir: {0}".format(sourceCfgDir))
    if dest is None:
        dest = context.dble_test_config['dble_host']

    node = get_node(context.dbles, dest)

    osCmd = 'rm -rf {0} && cp -r {0}_bk {0}'.format(sourceCfgDir)
    os.system(osCmd)

    cmd = 'rm -rf {0}/dble/conf_*'.format(context.dble_test_config['dble_basepath'])
    node.sshconn.exec_command(cmd)
    cmd = 'cp -r {0}/dble/conf {0}/dble/conf_bk'.format(context.dble_test_config['dble_basepath'])
    node.sshconn.exec_command(cmd)

    files = os.listdir(sourceCfgDir)
    for file in files:
        local_file = "{0}/{1}".format(sourceCfgDir, file)
        remove_file = "{0}/dble/conf/{1}".format(context.dble_test_config['dble_basepath'], file)
        node.sftp_conn.sftp_put(remove_file, local_file)

    restart_dble(context, dest)