﻿# ----------------------------------------------------------------------------------
#
# Copyright Microsoft Corporation
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# http://www.apache.org/licenses/LICENSE-2.0
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# ----------------------------------------------------------------------------------

# This script is to generate a set of operation and parameter cmdlets that
# are mapped from the source client library. 
#
# For example, 'ComputeManagementClient.VirtualMachines.Start()' would be
# 'Invoke-AzureVirtualMachineStartMethod'.
#
# It's also possible to map the actual verb from function to cmdlet, e.g.
# the above example would be 'Start-AzureVirtualMachine', but to keep it
# simple and consistent, we would like to use the generic verb.

[CmdletBinding()]
param(
    # The folder that contains the source DLL, and all its dependency DLLs.
    [Parameter(Mandatory = $true)]
    [string]$dllFolder,

    # The target output folder, and the generated files would be organized in
    # the sub-folder called 'Generated'.
    [Parameter(Mandatory = $true)]
    [string]$outFolder,
    
    # The namespace of the Compute client library
    [Parameter(Mandatory = $true)]
    [string]$client_library_namespace = 'Microsoft.WindowsAzure.Management.Compute',

    # The base cmdlet from which all automation cmdlets derive
    [Parameter(Mandatory = $true)]
    [string]$baseCmdletFullName = 'Microsoft.WindowsAzure.Commands.Utilities.Common.ServiceManagementBaseCmdlet',

    # The property field to access the client wrapper class from the base cmdlet
    [Parameter(Mandatory = $true)]
    [string]$base_class_client_field = 'ComputeClient',
    
    # Cmdlet Code Generation Style
    # 1. Invoke (default) that uses Invoke as the verb, and Operation + Method (e.g. VirtualMachine + Get)
    # 2. Verb style that maps the method name to a certain common PS verb (e.g. CreateOrUpdate -> New)
    [Parameter(Mandatory = $false)]
    [string]$cmdletStyle = 'Invoke'
)

$new_line_str = "`r`n";
$verbs_common_new = "VerbsCommon.New";
$verbs_lifecycle_invoke = "VerbsLifecycle.Invoke";
$client_model_namespace = $client_library_namespace + '.Models';

Write-Verbose "=============================================";
Write-Verbose "Input Parameters:";
Write-Verbose "DLL Folder            = $dllFolder";
Write-Verbose "Out Folder            = $outFolder";
Write-Verbose "Client NameSpace      = $client_library_namespace";
Write-Verbose "Model NameSpace       = $client_model_namespace";
Write-Verbose "Base Cmdlet Full Name = $baseCmdletFullName";
Write-Verbose "Base Client Name      = $base_class_client_field";
Write-Verbose "Cmdlet Style          = $cmdletStyle";
Write-Verbose "=============================================";
Write-Verbose "${new_line_str}";

$code_common_namespace = ($client_library_namespace.Replace('.Management.', '.Commands.')) + '.Automation';

$code_common_usings = @(
    'System',
    'System.Management.Automation'
);

$code_common_header =
@"
// 
// Copyright (c) Microsoft and contributors.  All rights reserved.
// 
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//   http://www.apache.org/licenses/LICENSE-2.0
// 
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// 
// See the License for the specific language governing permissions and
// limitations under the License.
// 

// Warning: This code was generated by a tool.
// 
// Changes to this file may cause incorrect behavior and will be lost if the
// code is regenerated.
"@;

function Get-SortedUsings
{
    param(
        # Sample: @('System.Management.Automation', 'Microsoft.Azure', ...)
        [Parameter(Mandatory = $true)]
        $common_using_str_list,

        # Sample: 'Microsoft.WindowsAzure.Management.Compute'
        [Parameter(Mandatory = $true)]
        $client_library_namespace
    )

    $list_of_usings = @() + $common_using_str_list + $client_library_namespace + $client_model_namespace;
    $sorted_usings = $list_of_usings | Sort-Object -Unique | foreach { "using ${_};" };

    $text = [string]::Join($new_line_str, $sorted_usings);

    return $text;
}

$code_using_strs = Get-SortedUsings $code_common_usings $client_library_namespace;

function Get-NormalizedName
{
    param(
        # Sample: 'vmName' => 'VMName', 'resourceGroup' => 'ResourceGroup', etc.
        [Parameter(Mandatory = $True)]
        [string]$inputName
    )

    if ([string]::IsNullOrEmpty($inputName))
    {
        return $inputName;
    }

    if ($inputName.StartsWith('vm'))
    {
        $outputName = 'VM' + $inputName.Substring(2);
    }
    else
    {
        [char]$firstChar = $inputName[0];
        $firstChar = [System.Char]::ToUpper($firstChar);
        $outputName = $firstChar + $inputName.Substring(1);
    }

    return $outputName;
}

function Get-NormalizedTypeName
{
    param(
        # Sample: 'System.String' => 'string', 'System.Boolean' => bool, etc.
        [Parameter(Mandatory = $True)]
        [string]$inputName
    )

    if ([string]::IsNullOrEmpty($inputName))
    {
        return $inputName;
    }

    $outputName = $inputName;
    $client_model_namespace_prefix = $client_model_namespace + '.';

    if ($inputName -eq 'System.String')
    {
        $outputName = 'string';
    }
    elseif ($inputName -eq 'System.Boolean')
    {
        $outputName = 'bool';
    }
    elseif ($inputName.StartsWith($client_model_namespace_prefix))
    {
        $outputName = $inputName.Substring($client_model_namespace_prefix.Length);
    }

    $outputName = $outputName.Replace('+', '.');

    return $outputName;
}

function Get-OperationShortName
{
    param(
        # Sample #1: 'IVirtualMachineOperations' => 'VirtualMachine'
        # Sample #2: 'IDeploymentOperations' => 'Deployment'
        [Parameter(Mandatory = $True)]
        [string]$opFullName
    )

    $prefix = 'I';
    $suffix = 'Operations';
    $opShortName = $opFullName;

    if ($opFullName.StartsWith($prefix) -and $opShortName.EndsWith($suffix))
    {
        $lenOpShortName = ($opShortName.Length - $prefix.Length - $suffix.Length);
        $opShortName = $opShortName.Substring($prefix.Length, $lenOpShortName);
    }

    return $opShortName;
}

# Sample: ServiceName, DeploymentName
function Is-PipingPropertyName
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$parameterName
    )

    if ($parameterName.ToLower() -eq 'servicename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'deploymentname')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'rolename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'roleinstancename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'vmimagename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'imagename')
    {
        return $true;
    }
    elseif ($parameterName.ToLower() -eq 'diskname')
    {
        return $true;
    }

    return $false;
}

function Is-PipingPropertyTypeName
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$parameterTypeName
    )
    
    if ($parameterTypeName.ToLower() -eq 'string')
    {
        return $true;
    }
    elseif ($parameterTypeName.ToLower() -eq 'system.string')
    {
        return $true;
    }

    return $false;
}

function Write-BaseCmdletFile
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$file_full_path,

        [Parameter(Mandatory = $True)]
        $operation_name_list,

        [Parameter(Mandatory = $True)]
        $client_class_info
    )

    [System.Reflection.PropertyInfo[]]$propItems = $client_class_info.GetProperties();

    $operation_get_code = "";
    foreach ($opFullName in $operation_name_list)
    {
        [string]$sOpFullName = $opFullName;
        Write-Verbose ('$sOpFullName = ' + $sOpFullName);
        $prefix = 'I';
        $suffix = 'Operations';
        if ($sOpFullName.StartsWith($prefix) -and $sOpFullName.EndsWith($suffix))
        {
            $opShortName = Get-OperationShortName $sOpFullName;
            $opPropName = $opShortName;
            foreach ($propItem in $propItems)
            {
                if ($propItem.PropertyType.Name -eq $opFullName)
                {
                    $opPropName = $propItem.Name;
                    break;
                }
            }

            $operation_get_template = 
@"
        public I${opShortName}Operations ${opShortName}Client
        {
            get
            {
                return ${base_class_client_field}.${opPropName};
            }
        }
"@;

            if (-not ($operation_get_code -eq ""))
            {
                $operation_get_code += ($new_line_str * 2);
            }

            $operation_get_code += $operation_get_template;
        }
    }

    $cmdlet_source_code_text =
@"
${code_common_header}

$code_using_strs

namespace ${code_common_namespace}
{
    public abstract class ComputeAutomationBaseCmdlet : $baseCmdletFullName
    {
${operation_get_code}
    }
}
"@;

    $st = Set-Content -Path $file_full_path -Value $cmdlet_source_code_text -Force;
}

# Sample: InvokeAzureVirtualMachineGetMethod.cs
function Write-OperationCmdletFile
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$fileOutputFolder,

        [Parameter(Mandatory = $True)]
        $opShortName,

        [Parameter(Mandatory = $True)]
        [System.Reflection.MethodInfo]$operation_method_info
    )

    $methodName = ($operation_method_info.Name.Replace('Async', ''));
    $cmdlet_verb = "Invoke";
    $cmdlet_verb_code = $verbs_common_new;
    $cmdlet_noun_prefix = 'Azure';
    $cmdlet_noun_suffix = 'Method';
    $cmdlet_noun = $cmdlet_noun_prefix + $opShortName + $methodName + $cmdlet_noun_suffix;
    $cmdlet_class_name = $cmdlet_verb + $cmdlet_noun;

    $file_full_path = $fileOutputFolder + '/' + $cmdlet_class_name + '.cs';
    if (Test-Path $file_full_path)
    {
        return;
    }

    $indents = " " * 8;
    $get_set_block = '{ get; set; }';
    
    $cmdlet_generated_code = '';
    # $cmdlet_generated_code += $indents + '// ' + $operation_method_info + $new_line_str;

    $params = $operation_method_info.GetParameters();
    [System.Collections.ArrayList]$param_names = @();
    foreach ($pt in $params)
    {
        $paramTypeFullName = $pt.ParameterType.FullName;
        if (-not ($paramTypeFullName.EndsWith('CancellationToken')))
        {
            $normalized_param_name = Get-NormalizedName $pt.Name;

            Write-Output ('    ' + $paramTypeFullName + ' ' + $normalized_param_name);

            $paramTypeNormalizedName = Get-NormalizedTypeName -inputName $paramTypeFullName;

            $param_attributes = $indents + "[Parameter(Mandatory = true";
            if ((Is-PipingPropertyName $normalized_param_name) -and (Is-PipingPropertyTypeName $paramTypeNormalizedName))
            {
                $piping_from_property_name_code = ", ValueFromPipelineByPropertyName = true";
                $param_attributes += $piping_from_property_name_code;
            }
            $param_attributes += ")]" + $new_line_str;
            $param_definition = $indents + "public ${paramTypeNormalizedName} ${normalized_param_name} " + $get_set_block + $new_line_str;
            $param_code_content = $param_attributes + $param_definition;

            $cmdlet_generated_code += $param_code_content + $new_line_str;

            $st = $param_names.Add($normalized_param_name);
        }
    }

    $params_join_str = [string]::Join(', ', $param_names.ToArray());

    $cmdlet_client_call_template =
@"
        public override void ExecuteCmdlet()
        {
            base.ExecuteCmdlet();
            ExecuteClientAction(() =>
            {
                var result = ${opShortName}Client.${methodName}(${params_join_str});
                WriteObject(result);
            });
        }
"@;

    $cmdlet_generated_code += $cmdlet_client_call_template;

    $cmdlt_source_template =
@"
${code_common_header}

$code_using_strs

namespace ${code_common_namespace}
{
    [Cmdlet(${cmdlet_verb_code}, `"${cmdlet_noun}`")]
    public class ${cmdlet_class_name} : ComputeAutomationBaseCmdlet
    {
${cmdlet_generated_code}
    }
}
"@;

    $st = Set-Content -Path $file_full_path -Value $cmdlt_source_template -Force;
}

# Sample: VirtualMachineCreateParameters
function Is-ClientComplexType
{
    param(
        [Parameter(Mandatory = $True)]
        $type_info
    )

    return ($type_info.Namespace -like "${client_name_space}.Model?") -and (-not $type_info.IsEnum);
}

# Sample: IList<ConfigurationSet>
function Is-ListComplexType
{
    param(
        [Parameter(Mandatory = $True)]
        $type_info
    )

    if ($type_info.IsGenericType)
    {
        $args = $list_item_type = $type_info.GetGenericArguments();

        if ($args.Count -eq 1)
        {
            $list_item_type = $type_info.GetGenericArguments()[0];

            if (Is-ClientComplexType $list_item_type)
            {
                return $true;
            }
        }
    }

    return $false;
}

# Sample: IList<ConfigurationSet> => ConfigurationSet
function Get-ListComplexItemType
{
    param(
        [Parameter(Mandatory = $True)]
        $type_info
    )

    if ($type_info.IsGenericType)
    {
        $args = $list_item_type = $type_info.GetGenericArguments();

        if ($args.Count -eq 1)
        {
            $list_item_type = $type_info.GetGenericArguments()[0];

            if (Is-ClientComplexType $list_item_type)
            {
                return $list_item_type;
            }
        }
    }

    return $null;
}

# Sample: VirtualMachines.Create(...) => VirtualMachineCreateParameters
function Get-MethodComplexParameter
{
    param(
        [Parameter(Mandatory = $True)]
        [System.Reflection.MethodInfo]$op_method_info,

        [Parameter(Mandatory = $True)]
        [string]$client_name_space
    )

    $params = $op_method_info.GetParameters();
    $paramsWithoutEnums = $params | where { -not $_.ParameterType.IsEnum };

    # Assume that each operation method has only one complext parameter type
    $param_info = $paramsWithoutEnums | where { $_.ParameterType.Namespace -like "${client_name_space}.Model?" } | select -First 1;

    return $param_info;
}

# Sample: VirtualMachineCreateParameters => ConfigurationSet, VMImageInput, ...
function Get-SubComplexParameterListFromType
{
    param(
        [Parameter(Mandatory = $True)]
        $type_info,

        [Parameter(Mandatory = $True)]
        [string]$client_name_space
    )

    $subParamTypeList = @();

    if (-not (Is-ClientComplexType $type_info))
    {
        return $subParamTypeList;
    }

    $paramProps = $type_info.GetProperties();
    foreach ($pp in $paramProps)
    {
        $isClientType = $false;
        if (Is-ClientComplexType $pp.PropertyType)
        {
            $subParamTypeList += $pp.PropertyType;
            $isClientType = $true;
        }
        elseif (Is-ListComplexType $pp.PropertyType)
        {
            $subParamTypeList += $pp.PropertyType;
            $subParamTypeList += Get-ListComplexItemType $pp.PropertyType;
            $isClientType = $true;
        }

        if ($isClientType)
        {
            $recursiveSubParamTypeList = Get-SubComplexParameterListFromType $pp.PropertyType $client_name_space;
            foreach ($rsType in $recursiveSubParamTypeList)
            {
                $subParamTypeList += $rsType;
            }
        }
    }

    return $subParamTypeList;
}

# Sample: VirtualMachineCreateParameters => ConfigurationSet, VMImageInput, ...
function Get-SubComplexParameterList
{
    param(
        [Parameter(Mandatory = $True)]
        [System.Reflection.ParameterInfo]$param_info,

        [Parameter(Mandatory = $True)]
        [string]$client_name_space
    )

    return Get-SubComplexParameterListFromType $param_info.ParameterType $client_name_space;
}

# Sample: NewAzureVirtualMachineCreateParameters.cs
function Write-ParameterCmdletFile
{
    param(
        [Parameter(Mandatory = $True)]
        [string]$fileOutputFolder,

        [Parameter(Mandatory = $True)]
        [string]$operation_short_name,

        [Parameter(Mandatory = $True)]
        $parameter_type_info,

        [Parameter(Mandatory = $false)]
        $is_list_type = $false
    )
    
    if (-not $is_list_type)
    {
        $param_type_full_name = $parameter_type_info.FullName;
        $param_type_full_name = $param_type_full_name.Replace('+', '.');

        $param_type_short_name = $parameter_type_info.Name;
        $param_type_short_name = $param_type_short_name.Replace('+', '.');

        $param_type_normalized_name = Get-NormalizedTypeName $parameter_type_info.FullName;
    }
    else
    {
        $itemType = $parameter_type_info.GetGenericArguments()[0];
        $itemTypeShortName = $itemType.Name;
        $itemTypeFullName = $itemType.FullName;
        $itemTypeNormalizedShortName = Get-NormalizedTypeName $itemTypeFullName;

        $param_type_full_name = "System.Collections.Generic.List<${itemTypeNormalizedShortName}>";
        $param_type_full_name = $param_type_full_name.Replace('+', '.');

        $param_type_short_name = "${itemTypeShortName}List";
        $param_type_short_name = $param_type_short_name.Replace('+', '.');

        $param_type_normalized_name = Get-NormalizedTypeName $param_type_full_name;
    }

    if (($param_type_short_name -like "${operation_short_name}*") -and ($param_type_short_name.Length -gt $operation_short_name.Length))
    {
        # Remove the common part between the parameter type name and operation short name, e.g. 'VirtualMachineDisk'
        $param_type_short_name = $param_type_short_name.Substring($operation_short_name.Length);
    }

    $cmdlet_verb = "New";
    $cmdlet_verb_code = $verbs_common_new;
    $cmdlet_noun_prefix = 'Azure';
    $cmdlet_noun_suffix = '';

    $cmdlet_noun = $cmdlet_noun_prefix + $operation_short_name + $param_type_short_name + $cmdlet_noun_suffix;
    $cmdlet_class_name = $cmdlet_verb + $cmdlet_noun;

    $file_full_path = $fileOutputFolder + '/' + $cmdlet_class_name + '.cs';
    if (Test-Path $file_full_path)
    {
        return;
    }

    # Construct Code Content
    $indents = " " * 8;
    $get_set_block = '{ get; set; }';
    
    $cmdlet_generated_code = '';

    $cmdlet_client_call_template =
@"
        public override void ExecuteCmdlet()
        {
            base.ExecuteCmdlet();
            var parameter = new ${param_type_normalized_name}();
            WriteObject(parameter);
        }
"@;

    $cmdlet_generated_code += $cmdlet_client_call_template;

    $cmdlt_source_template =
@"
${code_common_header}

$code_using_strs

namespace ${code_common_namespace}
{
    [Cmdlet(${cmdlet_verb_code}, `"${cmdlet_noun}`")]
    public class ${cmdlet_class_name} : ComputeAutomationBaseCmdlet
    {
${cmdlet_generated_code}
    }
}
"@;

    $st = Set-Content -Path $file_full_path -Value $cmdlt_source_template -Force;
}

# Code Generation Main Run
$outFolder += '/Generated';

$output = Get-ChildItem -Path $dllFolder | Out-String;

# Set-Content -Path ($outFolder + '/Output.txt');
Write-Verbose "List items under the folder: $dllFolder"
Write-Verbose $output;


$dllname = $client_library_namespace;
$dllfile = $dllname + '.dll';
$dllFileFullPath = $dllFolder + '\' + $dllfile;

if (-not (Test-Path -Path $dllFileFullPath))
{
    Write-Verbose "DLL file `'$dllFileFullPath`' not found. Exit.";
}
else
{
    $assembly = [System.Reflection.Assembly]::LoadFrom($dllFileFullPath);
    [System.Reflection.Assembly]::LoadWithPartialName("System.Collections.Generic");
    
    # All original types
    $types = $assembly.GetTypes();
    $filtered_types = $types | where { $_.Namespace -eq $dllname -and $_.Name -like 'I*Operations' };
    Write-Output ($filtered_types | select Namespace, Name);

    # Write Base Cmdlet File
    $baseCmdletFileFullName = $outFolder + '\' + 'ComputeAutomationBaseCmdlet.cs';
    $opNameList = ($filtered_types | select -ExpandProperty Name);
    $clientClassType = $types | where { $_.Namespace -eq $dllname -and $_.Name -eq 'IComputeManagementClient' };
    Write-BaseCmdletFile $baseCmdletFileFullName $opNameList $clientClassType;

    [System.Reflection.ParameterInfo[]]$parameter_type_info_list = @();

    # Write Operation Cmdlet Files
    foreach ($ft in $filtered_types)
    {
        Write-Output '';
        Write-Output '=============================================';
        Write-Output $ft.Name;
        Write-Output '=============================================';
    
        $opShortName = Get-OperationShortName $ft.Name;
        $opOutFolder = $outFolder + '/' + $opShortName;
        if (Test-Path -Path $opOutFolder)
        {
            $st = rmdir -Recurse -Force $opOutFolder;
        }
        $st = mkdir -Force $opOutFolder;

        $methods = $ft.GetMethods();
        foreach ($mt in $methods)
        {
            if ($mt.Name.StartsWith('Begin') -and $mt.Name.Contains('ing'))
            {
                # Skip 'BeginXXX' Calls for Now...
                continue;
            }

            Write-Output ($new_line_str + $mt.Name.Replace('Async', ''));
            Write-OperationCmdletFile $opOutFolder $opShortName $mt;

            [System.Reflection.ParameterInfo]$parameter_type_info = (Get-MethodComplexParameter $mt $client_library_namespace);

            if (($parameter_type_info -ne $null) -and (($parameter_type_info_list | where { $_.ParameterType.FullName -eq $parameter_type_info.FullName }).Count -eq 0))
            {
                $parameter_type_info_list += $parameter_type_info;

                Write-ParameterCmdletFile $opOutFolder $opShortName $parameter_type_info.ParameterType;

                # Run Through the Sub Parameter List
                $subParamTypeList = Get-SubComplexParameterList $parameter_type_info $client_library_namespace;

                if ($subParamTypeList.Count -gt 0)
                {
                    foreach ($sp in $subParamTypeList)
                    {
                        Write-Output ((' ' * 8) + $sp);
                        if (-not $sp.IsGenericType)
                        {
                            Write-ParameterCmdletFile $opOutFolder $opShortName $sp;
                        }
                        else
                        {
                            Write-ParameterCmdletFile $opOutFolder $opShortName $sp $true;
                        }
                    }
                }
            }
        }
    }

    Write-Output "=============================================";
    Write-Output "Finished.";
    Write-Output "=============================================";
}
