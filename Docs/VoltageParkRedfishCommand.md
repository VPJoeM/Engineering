# VoltagePark Redfish Command Interface

A command-line tool for managing Dell servers via the Redfish API. This tool allows for ACS control and fan speed management across multiple servers simultaneously.

## Features

- Check ACS (Access Control Services) status
- Enable/Disable ACS with automatic reboot
- Control fan speeds (Low/Medium/High)
- PSU (Power Supply Unit) inventory and status check
- Batch operations on multiple servers
- Credential management with secure storage
- Color-coded output for better visibility

## Prerequisites

- Network access to the iDRAC interfaces
- `curl` installed
- `jq` installed for JSON parsing
- `nc` (netcat) installed for connection testing

## Usage

1. Run the script:


2. First-time setup:
   - Enter your iDRAC credentials when prompted
   - Choose whether to save credentials for future use
   - Saved credentials are stored in `~/.redfish_creds`

3. Enter target IP addresses:
   - Type one IP address per line
   - Press CTRL+D (or CMD+D on Mac) when finished
   - The script will confirm the IPs being processed

4. Use the menu to select operations:
   ```
   1. Check ACS Status
   2. Set ACS Enabled and Reboot
   3. Set ACS Disabled and Reboot
   4. Set Fan Speed Low
   5. Set Fan Speed Medium
   6. Set Fan Speed High
   7. PSU Inventory Check
   8. Exit
   ```

## Command Details

### ACS Status Check
- Shows current and staged ACS settings
- Green indicates Enabled
- Red indicates Disabled

### ACS Control
- Option 2: Enables ACS and reboots
- Option 3: Disables ACS and reboots
- Automatic reboot is required for changes to take effect

### Fan Speed Control
- Low: Minimum fan speed
- Medium: Balanced fan speed
- High: Maximum fan speed
- Changes take effect immediately

### PSU Inventory Check
- Displays detailed power supply information including:
  - PSU model numbers
  - Serial numbers
  - Health status (color-coded)
    - Green: OK
    - Yellow: Warning
    - Red: Critical/Error
- Uses Redfish API to query power subsystem data
- Shows real-time status of each power supply unit

## Security Notes

- Credentials are stored in `~/.redfish_creds` with 600 permissions
- All connections use HTTPS (with -k for self-signed certs)
- Network timeouts are set to prevent hanging

## Troubleshooting

1. Connection Issues:
   - Script tests connectivity before operations
   - Verify network access to iDRAC ports
   - Check IP addresses are correct

2. Authentication Errors:
   - Delete `~/.redfish_creds` to reset credentials
   - Re-run script to enter new credentials

3. Operation Failures:
   - Check iDRAC logs for details
   - Verify iDRAC firmware is up to date
   - Ensure user has appropriate privileges

## Support

For issues or questions:
1. Check you are connected to the VPN 
2. Check iDRAC logs
2. Contact VoltagePark support team
3. Include any error messages in reports

## Maintenance

- Script location: `Support-Tooling/VoltageParkRedfishCommand.sh`
- Credentials: `~/.redfish_creds`
- Log files: Check iDRAC for operation logs

Remember to test any changes on a single server before performing batch operations across multiple systems.