
# SCRIPT: New-VMSeries.ps1
# ========================
# Creates a series of virtual machines in the Hyper-V client,
# each with its own virtual hard disk copied from a source VHD.
# This script must be run on the hypervisor, itself.
# 
# Version       : 1.01 - Checks available disk space before creating new VM's.
#               : 1.02 - Allows the user to specify which disk drive to use.
#               : 1.03 - Includes the option to add a virtual switch to each
#                        new VM's network adapter.
#               : 1.04 - Uses command shell parameters.
#
# Type          : Script
# Using         : Powershell
#
# Written by    : Andrew D.
# Last modified : 08/12/2015
#
# Prerequisites : Windows 2012 Server (Only tested on R2.)
#                 Hyper-V role must be enabled.
#                 A *.vhd (or *.vhdx) template must already be created.


# PARAMETER LIST
# --------------

# Defaulted
# ---------

# Drive        : The disk drive containing the Hyper-V directories.
#                   Must be punctuated. (EX: "E:")
# VMLocation   : The relative path of the Hyper-V file directory for VM's.
#                   Must be relative to the above drive. (EX: "Hyper-V\vm")
# VHDLocation  : The relative path of the Hyper-V vile directory for VHD's.
#                   Must be relative to the above drive. (EX: "Hyper-V\vhd")
# VMRAM        : The startup memory of each VM. (EX: 4096MB)
# VSwitch      : The virtual switch for each VM's network adapter.
#                   (It may be left empty.)
# Ext          : The VHD extension.

# Mandatory
# ---------

# VHDSource    : The name of the source for the VHD copies.
#                   (EX: "Windows_2012_Server.vhd")
# Prefix       : The general name for the new VM's and VHD's.
# First        : The index of the first VM being created.
# Last         : The index of the last VM being created.

Param
(
    [string] $Drive        = "E:",
    [string] $VMLocation   = "hyperv\vm\Virtual Machines",
    [string] $VHDLocation  = "hyperv\vhd",
    [int64]  $VMRAM        =  4096MB,
    [string] $VSwitch      = "",
    [string] $Ext          = ".vhd",
    
    [Parameter(Mandatory=$true)][string] $VHDSource,
    [Parameter(Mandatory=$true)][string] $Prefix,
    [Parameter(Mandatory=$true)][int16]  $First,
    [Parameter(Mandatory=$true)][int16]  $Last
)


# Runnable Script
# ---------------

Import-Module BitsTransfer

$count      =  0
$SourcePath = "$($Drive)\$($VHDLocation)\$($VHDSource)"
$SourcePath =  @{$true="$($SourcePath)"; $false="$($SourcePath)$($Ext)"}[$SourcePath -like "*.vhd"]
$VHDGen     =  @{$true=1; $false=2}[$Ext -eq ".vhd"]

# The names of the first VM and VHD.
$VMName     = "$($Prefix)$($First + $count)"
$VHDCopy    = "$($Drive)\$($VHDLocation)\$($Prefix)$($First + $count)$($Ext)"

# The size of the source VHD is compared against the amount of
# free space left on the hypervisor before another copy is attempted.

while( ( (Get-Item -Path $SourcePath).Length  -le  `
         (Get-PSDrive $Drive.Substring(0, $Drive.Length - 1)).Free )  -and `
       ( $First + $count++ -le $Last ) )
{
    # Makes a VHD copy.
    Start-BitsTransfer `
           -Source $SourcePath `
           -Destination $VHDCopy `
           -Description "Copying `"$($SourcePath)`" to `"$($VHDCopy)`"" `
           -DisplayName "Virtual Hard Disk Copy"
    
    echo "`nVHD $($count), copied."
    
    # Creates a new VM.
    New-VM -Name $VMName `
           -Path "$($Drive)\$($VMLocation)" `
           -Generation $VHDGen `
           -MemoryStartupBytes $VMRAM `
           -VHDPath $VHDCopy
    
	# If specified, adds a virtual switch to the new VM's network adapter.
    if(($VSwitch -ne "") -and ($VSwitch -ne $null))
    {
    	Get-VMSwitch $VSwitch | Connect-VMNetworkAdapter -VMName $VMName
    }
    
    echo "`nVM $($count), created.`n"

    # The names of the next VM and VHD.
    $VMName  = "$($Prefix)$($First + $count)"
    $VHDCopy = "$($Drive)\$($VHDLocation)\$($Prefix)$($First + $count)$($Ext)"
}

# Outputs an error message if the storage disk did not have enough space to create every VHD.
# It specifies the name of the last VM it tried to create.
if($First + $count -le $Last)
{
    $Host.UI.WriteErrorLine("`n$($VMName): There is not enough space on the disk to create the VHD.`n")
}