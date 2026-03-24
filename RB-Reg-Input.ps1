# Self-bypass execution policy + WinForms GUI
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope CurrentUser -Force

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Helper function for XAML loading (fixes parsing errors)
function ConvertFrom-XAML {
    param([string]$XamlString)
    $xamlDoc = New-Object System.Xml.XmlDocument
    $xamlDoc.LoadXml($XamlString)
    $reader = New-Object System.Xml.XmlNodeReader $xamlDoc
    try {
        return [Windows.Markup.XamlReader]::Load($reader)
    }
    catch {
        Write-Error "XAML Load Failed: $_"
        return $null
    }
}

# Registry path
$regPath = "HKLM:\Software\RBConfig"
$orderKey = "RBOrderNumber"
$licenseKey = "WindowsLicenseKey"

# Ensure registry key exists
if (-not (Test-Path $regPath)) {
    New-Item -Path $regPath -Force | Out-Null
}

# Read current values
$orderValue = (Get-ItemProperty -Path $regPath -Name $orderKey -ErrorAction SilentlyContinue).$orderKey
$licenseValue = (Get-ItemProperty -Path $regPath -Name $licenseKey -ErrorAction SilentlyContinue).$licenseKey

# Determine states
$orderComplete = [bool]$orderValue -and $orderValue.Trim()
$licenseComplete = [bool]$licenseValue -and $licenseValue.Trim()
$bothComplete = $orderComplete -and $licenseComplete

# XAML for WPF form
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="RB Configuration Setup" Height="320" Width="450"
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize" ShowInTaskbar="True">
    <Grid Margin="20">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        
        <Label Grid.Row="0" Content="RB Order Number:" FontWeight="Bold" Margin="0,0,0,5"/>
        <TextBox Grid.Row="1" x:Name="OrderTextBox" Height="28" Margin="0,0,0,15" TextWrapping="NoWrap" VerticalContentAlignment="Center"/>
        
        <Label Grid.Row="2" Content="Windows License Key:" FontWeight="Bold" Margin="0,0,0,5"/>
        <TextBox Grid.Row="3" x:Name="LicenseTextBox" Height="28" Margin="0,0,0,20" TextWrapping="NoWrap" VerticalContentAlignment="Center"/>
        
        <StackPanel Grid.Row="4" Orientation="Horizontal" HorizontalAlignment="Right">
            <Button x:Name="OKButton" Content="OK" Width="80" Height="32" Margin="0,0,10,0" IsDefault="True"/>
            <Button x:Name="CancelButton" Content="Cancel" Width="80" Height="32" IsCancel="True"/>
        </StackPanel>
    </Grid>
</Window>
"@

# Load form
$form = ConvertFrom-XAML -XamlString $xaml
if (-not $form) { exit 1 }

# Get controls
$orderTB = $form.FindName("OrderTextBox")
$licenseTB = $form.FindName("LicenseTextBox")
$okBtn = $form.FindName("OKButton")
$cancelBtn = $form.FindName("CancelButton")

if (-not ($orderTB -and $licenseTB -and $okBtn -and $cancelBtn)) {
    Write-Error "Failed to find UI controls"
    exit 1
}

# Set initial values and readonly
$orderTB.Text = if ($orderValue) { $orderValue } else { "" }
$orderTB.IsReadOnly = $orderComplete

$licenseTB.Text = if ($licenseValue) { $licenseValue } else { "" }
$licenseTB.IsReadOnly = $licenseComplete

if ($bothComplete) {
    $okBtn.IsEnabled = $false
    $okBtn.Content = "Complete"
    $form.Title = "RB Configuration - Already Set"
}

# Script-scoped result
$script:dialogResult = $null

# Event handlers
$okBtn.Add_Click({
    $script:dialogResult = "OK"
    $form.Close()
})

$cancelBtn.Add_Click({
    $script:dialogResult = "Cancel"
    $form.Close()
})

# Show modal dialog
$form.ShowDialog() | Out-Null

# Process OK
if ($script:dialogResult -eq "OK" -and -not $bothComplete) {
    $saved = $false
    if (-not $orderTB.IsReadOnly -and $orderTB.Text.Trim()) {
        Set-ItemProperty -Path $regPath -Name $orderKey -Value $orderTB.Text.Trim()
        $saved = $true
    }
    if (-not $licenseTB.IsReadOnly -and $licenseTB.Text.Trim()) {
        Set-ItemProperty -Path $regPath -Name $licenseKey -Value $licenseTB.Text.Trim()
        $saved = $true
    }
    
    # Self-delete if now complete (use $MyInvocation.MyCommand.Path for .ps1)
    $scriptPath = $MyInvocation.MyCommand.Path
    if ($scriptPath -and (Test-Path $scriptPath)) {
        $currentOrder = (Get-ItemProperty -Path $regPath -Name $orderKey -ErrorAction SilentlyContinue).$orderKey
        $currentLicense = (Get-ItemProperty -Path $regPath -Name $licenseKey -ErrorAction SilentlyContinue).$licenseKey
        if ($currentOrder -and $currentLicense) {
            Start-Sleep -Milliseconds 500  # Brief delay for dialog close
            Remove-Item -Path $scriptPath -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "Script completed." -ForegroundColor Green