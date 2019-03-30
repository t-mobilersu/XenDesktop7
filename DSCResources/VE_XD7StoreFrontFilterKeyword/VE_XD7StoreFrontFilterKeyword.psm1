<#	
    ===========================================================================
     Created with: 	SAPIEN Technologies, Inc., PowerShell Studio 2019 v5.6.157
     Created on:   	2/8/2019 12:12 PM
     Created by:   	CERBDM
     Organization: 	Cerner Corporation
     Filename:     	VE_XD7StoreFrontFilterKeyword.psm1
    -------------------------------------------------------------------------
     Module Name: VE_XD7StoreFrontFilterKeyword
    ===========================================================================
#>

Import-LocalizedData -BindingVariable localizedData -FileName VE_XD7StoreFrontFilterKeyword.Resources.psd1;

function Get-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $StoreName,

        [Parameter(ParameterSetName='WhiteList')]
        [System.String[]]
        $IncludeKeywords,

        [Parameter(ParameterSetName='BlackList')]
        [System.String[]]
        $ExcludeKeywords
    )

    begin {
        AssertXDModule -Name 'StoresModule','UtilsModule' -Path "$env:ProgramFiles\Citrix\Receiver StoreFront\Management"
    }
    process {
        Import-module Citrix.StoreFront -ErrorAction Stop -Verbose:$false
        $storefrontCmdletSearchPath = "$env:ProgramFiles\Citrix\Receiver StoreFront\Management"
        Import-Module (FindXDModule -Name 'UtilsModule' -Path $storefrontCmdletSearchPath) -Scope Global -Verbose:$false >$null *>&1
        Import-Module (FindXDModule -Name 'StoresModule' -Path $storefrontCmdletSearchPath) -Scope Global -Verbose:$false >$null *>&1

        try {
            Write-Verbose "Calling Get-STFStoreService for $StoreName"
            $StoreService = Get-STFStoreService | Where-object {$_.friendlyname -eq $StoreName};
            Write-Verbose "Calling Get-DSWebReceiversSummary"
            $Configuration = get-dsresourcefilterkeyword -SiteId ($StoreService.SiteId) -VirtualPath ($StoreService.VirtualPath)
        }
        catch {
            Write-Verbose "Trapped error getting web receiver communication. Error: $($Error[0].Exception.Message)"
        }

        $returnValue = @{
            StoreName = [System.String]$StoreName
            IncludeKeywords = [System.String[]]$Configuration.Include
            ExcludeKeywords = [System.String[]]$Configuration.Exclude
        }

        $returnValue
    }
}


function Set-TargetResource
{
    [CmdletBinding()]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $StoreName,

        [Parameter(ParameterSetName='WhiteList')]
        [System.String[]]
        $IncludeKeywords,

        [Parameter(ParameterSetName='BlackList')]
        [System.String[]]
        $ExcludeKeywords
    )

    begin {
        AssertXDModule -Name 'StoresModule','UtilsModule' -Path "$env:ProgramFiles\Citrix\Receiver StoreFront\Management"
    }
    process {
        Import-module Citrix.StoreFront -ErrorAction Stop -Verbose:$false
        $storefrontCmdletSearchPath = "$env:ProgramFiles\Citrix\Receiver StoreFront\Management"
        Import-Module (FindXDModule -Name 'UtilsModule' -Path $storefrontCmdletSearchPath) -Scope Global -Verbose:$false >$null *>&1
        Import-Module (FindXDModule -Name 'StoresModule' -Path $storefrontCmdletSearchPath) -Scope Global -Verbose:$false >$null *>&1

        try {
            Write-Verbose "Calling Get-STFStoreService for $StoreName"
            $StoreService = Get-STFStoreService | Where-object {$_.friendlyname -eq $StoreName};
        }
        catch {
            Write-Verbose "Trapped error getting web receiver user interface. Error: $($Error[0].Exception.Message)"
        }

        $ChangedParams = @{
            SiteId = $StoreService.SiteId
            VirtualPath = $StoreService.VirtualPath
        }
        $targetResource = Get-TargetResource @PSBoundParameters;
        foreach ($property in $PSBoundParameters.Keys) {
            if ($targetResource.ContainsKey($property)) {
                $expected = $PSBoundParameters[$property];
                $actual = $targetResource[$property];
                if ($actual) {
                    if ($PSBoundParameters[$property] -is [System.String[]]) {
                        if (Compare-Object -ReferenceObject $expected -DifferenceObject $actual) {
                            if (!($ChangedParams.ContainsKey($property))) {
                                Write-Verbose "Adding $property to ChangedParams"
                                $ChangedParams.Add($property,$PSBoundParameters[$property])
                            }
                        }
                    }
                    elseif ($expected -ne $actual) {
                        if (!($ChangedParams.ContainsKey($property))) {
                            Write-Verbose "Adding $property to ChangedParams"
                            $ChangedParams.Add($property,$PSBoundParameters[$property])
                        }
                    }
                }
                else {
                    if (!($ChangedParams.ContainsKey($property))) {
                        Write-Verbose "Adding $property to ChangedParams"
                        $ChangedParams.Add($property,$PSBoundParameters[$property])
                    }
                }
            }
        }

        $ChangedParams.Remove('StoreName')
        Write-Verbose "Calling Set-DSResourceFilterKeyword"
        Set-DSResourceFilterKeyword @ChangedParams
    }
}


function Test-TargetResource
{
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param
    (
        [parameter(Mandatory = $true)]
        [System.String]
        $StoreName,

        [System.String[]]
        $IncludeKeywords,

        [System.String[]]
        $ExcludeKeywords
    )

    $targetResource = Get-TargetResource @PSBoundParameters;
    $inCompliance = $true;
    foreach ($property in $PSBoundParameters.Keys) {
        if ($targetResource.ContainsKey($property)) {
            $expected = $PSBoundParameters[$property];
            $actual = $targetResource[$property];
            if ($PSBoundParameters[$property] -is [System.String[]]) {
                if ($actual) {
                    if (Compare-Object -ReferenceObject $expected -DifferenceObject $actual -ErrorAction silentlycontinue) {
                        Write-Verbose ($localizedData.ResourcePropertyMismatch -f $property, ($expected -join ','), ($actual -join ','));
                        $inCompliance = $false;
                    }
                }
                else {
                    Write-Verbose ($localizedData.ResourcePropertyMismatch -f $property, ($expected -join ','), ($actual -join ','));
                    $inCompliance = $false;
                }
            }
            elseif ($expected -ne $actual) {
                Write-Verbose ($localizedData.ResourcePropertyMismatch -f $property, $expected, $actual);
                $inCompliance = $false;
            }
        }
    }

    if ($inCompliance) {
        Write-Verbose ($localizedData.ResourceInDesiredState -f $DeliveryGroup);
    }
    else {
        Write-Verbose ($localizedData.ResourceNotInDesiredState -f $DeliveryGroup);
    }

    return $inCompliance;
}


$moduleRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent;

## Import the XD7Common library functions
$moduleParent = Split-Path -Path $moduleRoot -Parent;
Import-Module (Join-Path -Path $moduleParent -ChildPath 'VE_XD7Common');

Export-ModuleMember -Function *-TargetResource

