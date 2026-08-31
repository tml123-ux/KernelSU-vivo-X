use adb_client::ADBDeviceExt;
use adb_client::tcp::ADBTcpDevice;
use anyhow::{Context, Result, bail};
use log::{error, info};
use prop_rs_android::resetprop::ResetProp;
use prop_rs_android::sys_prop;
use std::net::{IpAddr, Ipv4Addr, SocketAddr};
use std::process::Command;

const fn resetprop() -> ResetProp {
    ResetProp {
        skip_svc: true,
        persistent: false,
        persist_only: false,
        verbose: false,
        show_context: false,
        rebuild: false,
    }
}

fn exec_shell_commands(commands: &[(&str, &[&str])], log_prefix: &str) -> Result<()> {
    for (cmd, args) in commands {
        info!("{log_prefix}: {cmd} {}", args.join(" "));
        let status = Command::new(cmd)
            .args(*args)
            .status()
            .with_context(|| format!("Failed to execute {cmd}"))?;
        if !status.success() {
            bail!("{cmd} {} exited with {status}", args.join(" "));
        }
    }
    Ok(())
}

#[allow(dead_code)]
fn enable_adb_root(port: u16) -> Result<()> {
    // We are in limited root by magica
    anyhow::ensure!(
        rustix::process::getuid().as_raw() == 0,
        "must be run as root"
    );

    sys_prop::init().context("Failed to initialize system property API")?;
    let rp = resetprop();

    let debuggable_context = sys_prop::get_context("ro.debuggable")
        .context("Failed to get context for ro.debuggable")?;
    info!("ro.debuggable context: {debuggable_context}");

    let adb_secure_context = sys_prop::get_context("ro.adb.secure")
        .context("Failed to get context for ro.adb.secure")?;
    info!("ro.adb.secure context: {adb_secure_context}");

    let props_serial = "/dev/__properties__/properties_serial";
    let debuggable_context = format!("/dev/__properties__/{debuggable_context}");
    let adb_secure_context = format!("/dev/__properties__/{adb_secure_context}");
    let port_str = port.to_string();

    // chmod property files to writable
    exec_shell_commands(
        &[
            ("chmod", &["0644", props_serial]),
            ("chmod", &["0644", &debuggable_context]),
            ("chmod", &["0644", &adb_secure_context]),
        ],
        "Executing",
    )?;

    // Set properties via internal API
    rp.set("ro.debuggable", "1")
        .context("Failed to set ro.debuggable")?;
    info!("Executing: resetprop -n ro.debuggable 1");
    rp.set("ro.adb.secure", "0")
        .context("Failed to set ro.adb.secure")?;
    info!("Executing: resetprop -n ro.adb.secure 0");

    // Restore permissions and restart adbd
    exec_shell_commands(
        &[
            ("chmod", &["0444", props_serial]),
            ("chmod", &["0444", &debuggable_context]),
            ("chmod", &["0444", &adb_secure_context]),
            ("setprop", &["service.adb.root", "1"]),
            ("setprop", &["service.adb.tcp.port", &port_str]),
            ("setprop", &["ctl.restart", "adbd"]),
        ],
        "Executing",
    )?;

    Ok(())
}

pub fn disable_adb_root() -> Result<()> {
    // We have full root now, no need to chmod
    sys_prop::init().context("Failed to initialize system property API")?;
    let rp = resetprop();

    info!("Restoring: resetprop -n ro.debuggable 0");
    rp.set("ro.debuggable", "0")
        .context("Failed to set ro.debuggable")?;

    info!("Restoring: resetprop -n ro.adb.secure 1");
    rp.set("ro.adb.secure", "1")
        .context("Failed to set ro.adb.secure")?;

    for prop in &[
        "service.adb.root",
        "service.adb.tcp.port",
        "ro.boot.selinux",
    ] {
        info!("Restoring: resetprop --delete {prop}");
        let _ = rp.delete(prop);
        if let Ok(ctx) = sys_prop::get_context(prop) {
            let _ = rp.rebuild(&ctx);
        }
    }

    exec_shell_commands(&[("setprop", &["ctl.restart", "adbd"])], "Restoring")?;

    Ok(())
}

#[allow(dead_code)]
fn connect_to_device(port: u16) -> Result<ADBTcpDevice> {
    const MAX_RETRIES: u32 = 30;
    for attempt in 1..=MAX_RETRIES {
        info!("Waiting for adbd to restart... (attempt {attempt}/{MAX_RETRIES})");
        std::thread::sleep(std::time::Duration::from_secs(1));

        let addr = SocketAddr::new(IpAddr::V4(Ipv4Addr::LOCALHOST), port);
        info!("Connecting to ADB device at {addr}");
        match ADBTcpDevice::new(addr).context("Failed to create ADBTcpDevice") {
            Ok(device) => return Ok(device),
            Err(e) => {
                error!("Failed to connect to ADB device: {e:?}, retry after 1s");
            }
        }
    }
    bail!("Failed to connect to ADB device after {MAX_RETRIES} attempts")
}

pub fn run(port: u16, package_name: &String, allow_shell: bool) -> Result<()> {
    // Magica auto-activation is disabled on this device.
    //
    // The AppZygote preload child (forked by AppZygotePreload) inherits
    // AppZygote's seccomp filter. The kernel only whitelists the reboot
    // syscall for the manager uid via the setresuid hook, and the child
    // uses setuid(0) (not setresuid), so ksuinit::has_kernelsu() always
    // returns false here. Falling through to enable_adb_root() + late-load
    // from this context restarts adbd and reloads the kernel module while
    // the system is mid-boot, which destabilizes the device and ends in a
    // freeze + reboot.
    //
    // Activation on this device is done manually with:
    //   <libksud.so> late-load --allow-shell --package-name me.weishu.kernelsu
    // so magica simply does nothing.
    let _ = (port, package_name, allow_shell);
    info!("magica auto-activation disabled on this device, skip");
    Ok(())
}
