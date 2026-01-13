# Refactoring Guide: Creating a Parameterized Azure Cost Diff Script

This guide will help you refactor `diff_resource_nov_dec.ps1` and `diff_resource_sept_oct.ps1` into a single parameterized script.

## Overview

Both scripts are nearly identical except for:
- Month-specific variable names
- Hard-coded date ranges
- Month names in labels and output

## Step-by-Step Refactoring Instructions

### Step 1: Create the New Script File

Create a new file: `finops/diff_resource/diff_resource.ps1`

### Step 2: Add Parameters at the Top

```powershell
param(
    [Parameter(Mandatory=$true, HelpMessage="Source month in format YYYY-MM (e.g., 2025-11)")]
    [string]$SourceMonth,
    
    [Parameter(Mandatory=$true, HelpMessage="Target month in format YYYY-MM (e.g., 2025-12)")]
    [string]$TargetMonth,
    
    [Parameter(Mandatory=$false)]
    [double]$SignificantChangeThreshold = 0.5,
    
    [Parameter(Mandatory=$false)]
    [double]$MinimumCostThreshold = 1.0
)
```

### Step 3: Calculate Date Ranges Dynamically

Add this code after the parameters:

```powershell
# Parse and validate source month
try {
    $sourceDate = [DateTime]::ParseExact($SourceMonth, "yyyy-MM", $null)
    $fromSource = $sourceDate.ToString("yyyy-MM-01")
    $toSource = $sourceDate.AddMonths(1).AddDays(-1).ToString("yyyy-MM-dd")
    $sourceMonthName = $sourceDate.ToString("MMMM yyyy")
} catch {
    Write-Error "Invalid SourceMonth format. Use YYYY-MM (e.g., 2025-11)"
    exit 1
}

# Parse and validate target month
try {
    $targetDate = [DateTime]::ParseExact($TargetMonth, "yyyy-MM", $null)
    $fromTarget = $targetDate.ToString("yyyy-MM-01")
    $toTarget = $targetDate.AddMonths(1).AddDays(-1).ToString("yyyy-MM-dd")
    $targetMonthName = $targetDate.ToString("MMMM yyyy")
} catch {
    Write-Error "Invalid TargetMonth format. Use YYYY-MM (e.g., 2025-12)"
    exit 1
}

# Create labels for output
$sourceLabel = "Source: ($fromSource to $toSource)"
$targetLabel = "Target: ($fromTarget to $toTarget)"
```

### Step 4: Copy Helper Functions (No Changes Needed)

Copy these functions as-is from either original script:
- `ItemKey($r)`
- `ItemName($r)`
- `ResourceDisplayName($r)`
- `Center([string]$text, [int]$width = 90)`

### Step 5: Refactor `Detect-CostAnomalies` Function

**Key Changes:**
- Rename parameters: `$NovData` → `$SourceData`, `$DecData` → `$TargetData`
- Add parameters: `$SourceMonthName`, `$TargetMonthName`
- Rename internal variables: `$novMap` → `$sourceMap`, `$decMap` → `$targetMap`
- Use generic property names in PSCustomObjects: `SourceCost`, `TargetCost`

```powershell
function Detect-CostAnomalies {
    param(
        [array]$SourceData,
        [array]$TargetData,
        [string]$SourceMonthName,
        [string]$TargetMonthName,
        [double]$SignificantChangeThreshold = 0.5,
        [double]$MinimumCostThreshold = 1.0
    )
    
    # Build SUM maps (key -> total cost)
    $sourceMap = @{}
    foreach ($r in $SourceData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($sourceMap.ContainsKey($k)) { $sourceMap[$k] += $c } else { $sourceMap[$k] = $c }
    }

    $targetMap = @{}
    foreach ($r in $TargetData) {
        $k = ItemKey $r
        $c = [double]$r.Cost
        if ($targetMap.ContainsKey($k)) { $targetMap[$k] += $c } else { $targetMap[$k] = $c }
    }
    
    $anomalies = @()
    
    # Check all resources in target data
    foreach ($k in $targetMap.Keys) {
        $targetCost = [double]$targetMap[$k]
        $sourceCost = [double]($sourceMap[$k] ?? 0)
        $change = $targetCost - $sourceCost
        $percentChange = if ($sourceCost -ne 0) { [math]::Abs($change / $sourceCost) } else { [double]::PositiveInfinity }
        
        # Skip if below minimum cost threshold
        if ($targetCost -lt $MinimumCostThreshold -and $sourceCost -lt $MinimumCostThreshold) {
            continue
        }
        
        # Check for new costs
        if (($sourceCost -eq 0 -or -not $sourceMap.ContainsKey($k)) -and $targetCost -ge $MinimumCostThreshold) {
            $rep = $TargetData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "NewCost"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                SourceCost = $sourceCost
                TargetCost = $targetCost
                Change = $change
                PercentChange = if ($sourceCost -eq 0) { "N/A" } else { ("{0:P2}" -f $percentChange) }
                Message = "New cost detected"
            }
        }
        # Check for removed costs
        elseif ($sourceCost -ge $MinimumCostThreshold -and $targetCost -eq 0) {
            $rep = $SourceData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "RemovedCost"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                SourceCost = $sourceCost
                TargetCost = $targetCost
                Change = $change
                PercentChange = ("{0:P2}" -f $percentChange)
                Message = "Cost removed"
            }
        }
        # Check for significant changes
        elseif ($sourceCost -ge $MinimumCostThreshold -and $targetCost -ge $MinimumCostThreshold -and $percentChange -ge $SignificantChangeThreshold) {
            $rep = $TargetData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1
            $anomalies += [PSCustomObject]@{
                Type = "SignificantChange"
                Name = (ResourceDisplayName $rep)
                Service = $rep.ServiceName
                ResourceGroup = $rep.ResourceGroupName
                Location = $rep.ResourceLocation
                SourceCost = $sourceCost
                TargetCost = $targetCost
                Change = $change
                PercentChange = ("{0:P2}" -f $percentChange)
                Message = if ($change -gt 0) { "Significant cost increase" } else { "Significant cost decrease" }
            }
        }
    }
    
    return $anomalies
}
```

### Step 6: Refactor `Append-AnomaliesToFile` Function

**Key Changes:**
- Add parameters: `$SourceMonthName`, `$TargetMonthName`
- Update property references: `$_.NovemberCost` → `$_.SourceCost`, `$_.DecemberCost` → `$_.TargetCost`
- Update column headers to use month names dynamically

```powershell
function Append-AnomaliesToFile {
    param(
        [array]$Anomalies,
        [string]$Currency,
        [string]$OutFile,
        [string]$SourceMonthName,
        [string]$TargetMonthName
    )
    
    if ($Anomalies.Count -eq 0) {
        "`nNo anomalies detected" | Out-File $OutFile -Encoding utf8 -Append
        return
    }
    
    "`n=== DETECTED ANOMALIES ===" | Out-File $OutFile -Encoding utf8 -Append
    
    # Group by type
    $newCosts = $Anomalies | Where-Object { $_.Type -eq "NewCost" }
    $removedCosts = $Anomalies | Where-Object { $_.Type -eq "RemovedCost" }
    $significantChanges = $Anomalies | Where-Object { $_.Type -eq "SignificantChange" } | Sort-Object Change -Descending
    
    # Append new costs
    if ($newCosts.Count -gt 0) {
        "`n💰 NEW COSTS DETECTED:" | Out-File $OutFile -Encoding utf8 -Append
        $newCosts | Sort-Object Change -Descending | Select-Object -First 10 |
            Format-Table -Property @(
                @{Name="Resource"; Expression={ if ($_.Name.Length -gt 50) { $_.Name.Substring(0,50) + "…" } else { $_.Name } }},
                @{Name="Service"; Expression={ $_.Service }},
                @{Name="Resource Group"; Expression={ $_.ResourceGroup }},
                @{Name="Location"; Expression={ $_.Location }},
                @{Name=$SourceMonthName; Expression={ "{0:N2} {1}" -f $_.SourceCost, $Currency }},
                @{Name=$TargetMonthName; Expression={ "{0:N2} {1}" -f $_.TargetCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    # Append removed costs
    if ($removedCosts.Count -gt 0) {
        "`n💸 COSTS REMOVED:" | Out-File $OutFile -Encoding utf8 -Append
        $removedCosts | Sort-Object Change | Select-Object -First 10 |
            Format-Table -Property @(
                @{Name="Resource"; Expression={ if ($_.Name.Length -gt 50) { $_.Name.Substring(0,50) + "…" } else { $_.Name } }},
                @{Name="Service"; Expression={ $_.Service }},
                @{Name="Resource Group"; Expression={ $_.ResourceGroup }},
                @{Name="Location"; Expression={ $_.Location }},
                @{Name=$SourceMonthName; Expression={ "{0:N2} {1}" -f $_.SourceCost, $Currency }},
                @{Name=$TargetMonthName; Expression={ "{0:N2} {1}" -f $_.TargetCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    # Append significant changes
    if ($significantChanges.Count -gt 0) {
        "`n📊 SIGNIFICANT COST CHANGES:" | Out-File $OutFile -Encoding utf8 -Append
        $significantChanges | Select-Object -First 15 |
            Format-Table -Property @(
                @{Name="Resource"; Expression={ if ($_.Name.Length -gt 50) { $_.Name.Substring(0,50) + "…" } else { $_.Name } }},
                @{Name="Service"; Expression={ $_.Service }},
                @{Name="Resource Group"; Expression={ $_.ResourceGroup }},
                @{Name="Location"; Expression={ $_.Location }},
                @{Name=$SourceMonthName; Expression={ "{0:N2} {1}" -f $_.SourceCost, $Currency }},
                @{Name=$TargetMonthName; Expression={ "{0:N2} {1}" -f $_.TargetCost, $Currency }},
                @{Name="Change"; Expression={ "{0}{1:N2} {2}" -f $(if ($_.Change -ge 0){"+"}else{""}), $_.Change, $Currency }},
                @{Name="Percent"; Expression={ $_.PercentChange }}
            ) | Out-String -Width 500 | Out-File $OutFile -Encoding utf8 -Append
    }
    
    "`nTotal anomalies detected: $($Anomalies.Count)" | Out-File $OutFile -Encoding utf8 -Append
}
```

### Step 7: Refactor the Main Processing Loop

**Key Changes:**
- Use `$fromSource`, `$toSource`, `$fromTarget`, `$toTarget` instead of hard-coded dates
- Rename variables: `$nov` → `$sourceData`, `$dec` → `$targetData`
- Rename maps: `$novMap` → `$sourceMap`, `$decMap` → `$targetMap`
- Update file names to use month parameters
- Update property names in diff objects

```powershell
# ---- Process each subscription ----
$subs = az account list --query "[].id" -o tsv

foreach ($id in $subs) {
  $id = $id.Trim()
  if (-not $id) { continue }

  Write-Host "`n=== Subscription: $id ==="

  $sourceFile = "$SourceMonth-resources-$id.json"
  $targetFile = "$TargetMonth-resources-$id.json"
  $outFile = "diff-resources-$SourceMonth-$TargetMonth-top50-$id.txt"

  # Export source month
  azure-cost costByResource -s $id --timeframe Custom --from $fromSource --to $toSource -o json |
    Out-File $sourceFile -Encoding utf8
  if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Source export failed)"; continue }
  if (-not (Test-Path $sourceFile) -or (Get-Item $sourceFile).Length -eq 0) { Write-Warning "Skipping $id (Source empty)"; continue }

  # Export target month
  azure-cost costByResource -s $id --timeframe Custom --from $fromTarget --to $toTarget -o json |
    Out-File $targetFile -Encoding utf8
  if ($LASTEXITCODE -ne 0) { Write-Warning "Skipping $id (Target export failed)"; continue }
  if (-not (Test-Path $targetFile) -or (Get-Item $targetFile).Length -eq 0) { Write-Warning "Skipping $id (Target empty)"; continue }

  # Load JSON
  $sourceData = Get-Content $sourceFile -Raw | ConvertFrom-Json
  $targetData = Get-Content $targetFile -Raw | ConvertFrom-Json

  # Determine currency
  $currency = ($targetData | Where-Object Currency | Select-Object -First 1 -ExpandProperty Currency)
  if (-not $currency) { $currency = "EUR" }

  # Build SUM maps
  $sourceMap = @{}
  foreach ($r in $sourceData) {
    $k = ItemKey $r
    $c = [double]$r.Cost
    if ($sourceMap.ContainsKey($k)) { $sourceMap[$k] += $c } else { $sourceMap[$k] = $c }
  }

  $targetMap = @{}
  foreach ($r in $targetData) {
    $k = ItemKey $r
    $c = [double]$r.Cost
    if ($targetMap.ContainsKey($k)) { $targetMap[$k] += $c } else { $targetMap[$k] = $c }
  }

  # Build diff rows
  $diff = foreach ($k in $targetMap.Keys) {
    $targetCost = [double]$targetMap[$k]
    $sourceCost = [double]($sourceMap[$k] ?? 0)
    $change  = $targetCost - $sourceCost

    if ($change -le 0) { continue }

    $rep = $targetData | Where-Object { (ItemKey $_) -eq $k } | Select-Object -First 1

    [pscustomobject]@{
      Name        = (ResourceDisplayName $rep)
      Service     = $rep.ServiceName
      Location    = $rep.ResourceLocation
      ResourceGrp = $rep.ResourceGroupName
      Source      = [math]::Round($sourceCost, 3)
      Target      = [math]::Round($targetCost, 3)
      Change      = [math]::Round($change, 3)
      IsNew       = (-not $sourceMap.ContainsKey($k) -or $sourceCost -eq 0)
    }
  }

  # Top 50 by increase
  $top50 = $diff | Sort-Object Change -Descending | Select-Object -First 50

  # Write header
  @(
    Center "Azure Cost Diff (Resource Level)"
    Center $sourceLabel
    Center $targetLabel
    ""
  ) | Out-File $outFile -Encoding utf8

  # Write table
  $top50 |
    Select-Object `
      Service,
      ResourceGrp,
      Location,
      @{n="Source";e={ "{0:N2} {1}" -f $_.Source, $currency }},
      @{n="Target";e={ "{0:N2} {1}" -f $_.Target, $currency }},
      @{n="Change";e={ "{0}{1:N2} {2}" -f ($(if ($_.Change -ge 0){"+"}else{""})), $_.Change, $currency }},
      @{n="New?";e={ if ($_.IsNew) { "YES" } else { "" } }},
      @{n="Name";e={ if ($_.Name.Length -gt 140) { $_.Name.Substring(0,140) + "…" } else { $_.Name } }} |
    Format-Table -AutoSize -Wrap |
    Out-String -Width 500 |
    Out-File $outFile -Encoding utf8 -Append

  # Append Summary
  $srcTotal = ($diff | Measure-Object Source -Sum).Sum
  $tgtTotal = ($diff | Measure-Object Target -Sum).Sum
  $chgTotal = ($diff | Measure-Object Change -Sum).Sum

  "" | Out-File $outFile -Encoding utf8 -Append
  "Summary" | Out-File $outFile -Encoding utf8 -Append
  "-------" | Out-File $outFile -Encoding utf8 -Append

  @(
    [pscustomobject]@{
      Comparison = "TOTAL COSTS (new + increases)"
      Source     = ("{0:N2} {1}" -f $srcTotal, $currency)
      Target     = ("{0:N2} {1}" -f $tgtTotal, $currency)
      Change     = ("{0}{1:N2} {2}" -f ($(if ($chgTotal -ge 0){"+"}else{""})), $chgTotal, $currency)
    }
  ) |
    Format-Table -AutoSize |
    Out-String -Width 200 |
    Out-File $outFile -Encoding utf8 -Append

  Write-Host "Saved: $outFile"

  # Detect and append anomalies
  $anomalies = Detect-CostAnomalies -SourceData $sourceData -TargetData $targetData `
    -SourceMonthName $sourceMonthName -TargetMonthName $targetMonthName `
    -SignificantChangeThreshold $SignificantChangeThreshold -MinimumCostThreshold $MinimumCostThreshold
  
  Append-AnomaliesToFile -Anomalies $anomalies -Currency $currency -OutFile $outFile `
    -SourceMonthName $sourceMonthName -TargetMonthName $targetMonthName

  Write-Host "Anomalies appended to: $outFile"
}
```

## Testing Your Refactored Script

### Test Case 1: November to December
```powershell
.\diff_resource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12"
```

### Test Case 2: September to October
```powershell
.\diff_resource.ps1 -SourceMonth "2025-09" -TargetMonth "2025-10"
```

### Test Case 3: Custom Thresholds
```powershell
.\diff_resource.ps1 -SourceMonth "2025-11" -TargetMonth "2025-12" `
  -SignificantChangeThreshold 0.75 -MinimumCostThreshold 5.0
```

## Checklist

- [ ] Created new file `diff_resource.ps1`
- [ ] Added parameters at the top
- [ ] Added date calculation logic
- [ ] Copied helper functions unchanged
- [ ] Refactored `Detect-CostAnomalies` function
- [ ] Refactored `Append-AnomaliesToFile` function
- [ ] Refactored main processing loop
- [ ] Tested with November-December data
- [ ] Tested with September-October data
- [ ] Verified output files are correct
- [ ] (Optional) Deleted old scripts after verification

## Common Pitfalls to Avoid

1. **Forgetting to update property names** in PSCustomObjects (e.g., `NovemberCost` → `SourceCost`)
2. **Missing month name parameters** when calling functions
3. **Hard-coded month names** in string literals
4. **Inconsistent variable naming** (mixing `source`/`target` with month names)
5. **Not handling date parsing errors** gracefully

## Benefits of This Refactoring

✅ Single script to maintain instead of two  
✅ Works with any month combination  
✅ Reduces code duplication  
✅ Easier to add new features (only one place to update)  
✅ Configurable thresholds via parameters  
✅ Better error handling with date validation
