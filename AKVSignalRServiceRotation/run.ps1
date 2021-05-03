param($eventGridEvent, $TriggerMetadata)

function RegenerateCredential($credentialId, $providerAddress){
    Write-Host "Regenerating credential. Id: $credentialId Resource Id: $providerAddress"
    
    #Write code to regenerate credential, update your service with new credential and return it

    #EXAMPLE FOR STORAGE

    <#  
    $signalRServiceName = ($providerAddress -split '/')[8]
    $resourceGroupName = ($providerAddress -split '/')[4]
    
    #Regenerate key 
    $operationResult = New-AzsignalRServiceKey -ResourceGroupName $resourceGroupName -Name $signalRServiceName -KeyName $credentialId
    $newCredentialValue = (Get-AzsignalRServiceKey -ResourceGroupName $resourceGroupName -AccountName $signalRServiceName|where KeyName -eq $credentialId).value 
    return $newCredentialValue
    
    #>

    $signalRServiceName = ($providerAddress -split '/')[8]
    $resourceGroupName = ($providerAddress -split '/')[4]
    
    #Regenerate key 
    #https://docs.microsoft.com/en-us/powershell/module/az.signalr/new-azsignalrkey
    #https://docs.microsoft.com/en-us/powershell/module/az.signalr/get-azsignalrkey
    If ($credentialId -eq "key1") {
        $operationResult = New-AzSignalRKey -ResourceGroupName $resourceGroupName -Name $signalRServiceName -KeyType Primary
        $newCredentialValue = (Get-AzSignalRKey -ResourceGroupName $resourceGroupName -Name $signalRServiceName).PrimaryKey
    } Else {
        $operationResult = New-AzSignalRKey -ResourceGroupName $resourceGroupName -Name $signalRServiceName -KeyType Secondary
        $newCredentialValue = (Get-AzSignalRKey -ResourceGroupName $resourceGroupName -Name $signalRServiceName).SecondaryKey
    }
    return $newCredentialValue
}

function GetAlternateCredentialId($credentialId){
    #Write code to get alternate credential id for your service

   #EXAMPLE FOR STORAGE

   <#
   $validCredentialIdsRegEx = 'key[1-2]'
   
   If($credentialId -NotMatch $validCredentialIdsRegEx){
       throw "Invalid credential id: $credentialId. Credential id must follow this pattern:$validCredentialIdsRegEx"
   }
   If($credentialId -eq 'key1'){
       return "key2"
   }
   Else{
       return "key1"
   }
   #>

    # it's possible this should all be primary / secondary...
    $validCredentialIdsRegEx = 'key[1-2]'
   
    If($credentialId -NotMatch $validCredentialIdsRegEx){
        throw "Invalid credential id: $credentialId. Credential id must follow this pattern:$validCredentialIdsRegEx"
    }
    If($credentialId -eq 'key1'){
        return "key2"
    } Else {
        return "key1"
    }
}

function AddSecretToKeyVault($keyVAultName,$secretName,$secretvalue,$exprityDate,$tags){
    
     Set-AzKeyVaultSecret -VaultName $keyVAultName -Name $secretName -SecretValue $secretvalue -Tag $tags -Expires $expiryDate

}

function RotateSecret($keyVaultName,$secretName,$secretVersion){
    #Retrieve Secret
    $secret = (Get-AzKeyVaultSecret -VaultName $keyVaultName -Name $secretName)
    Write-Host "Secret Retrieved"
    
    If($secret.Version -ne $secretVersion){
        #if current version is different than one retrived in event
        Write-Host "Secret version is already rotated"
        return 
    }

    #Retrieve Secret Info
    $validityPeriodDays = $secret.Tags["ValidityPeriodDays"]
    $credentialId=  $secret.Tags["CredentialId"]
    $providerAddress = $secret.Tags["ProviderAddress"]
    
    Write-Host "Secret Info Retrieved"
    Write-Host "Validity Period: $validityPeriodDays"
    Write-Host "Credential Id: $credentialId"
    Write-Host "Provider Address: $providerAddress"

    #Get Credential Id to rotate - alternate credential
    $alternateCredentialId = GetAlternateCredentialId $credentialId
    Write-Host "Alternate credential id: $alternateCredentialId"

    #Regenerate alternate access credential in provider
    $newCredentialValue = (RegenerateCredential $alternateCredentialId $providerAddress)
    Write-Host "Credential regenerated. Credential Id: $alternateCredentialId Resource Id: $providerAddress"

    #Add new credential to Key Vault
    $newSecretVersionTags = @{}
    $newSecretVersionTags.ValidityPeriodDays = $validityPeriodDays
    $newSecretVersionTags.CredentialId=$alternateCredentialId
    $newSecretVersionTags.ProviderAddress = $providerAddress

    $expiryDate = (Get-Date).AddDays([int]$validityPeriodDays).ToUniversalTime()
    $secretvalue = ConvertTo-SecureString "$newCredentialValue" -AsPlainText -Force
    AddSecretToKeyVault $keyVAultName $secretName $secretvalue $expiryDate $newSecretVersionTags

    Write-Host "New credential added to Key Vault. Secret Name: $secretName"
}
$ErrorActionPreference = "Stop"
# Make sure to pass hashtables to Out-String so they're logged correctly
$eventGridEvent | ConvertTo-Json | Write-Host

$secretName = $eventGridEvent.subject
$secretVersion = $eventGridEvent.data.Version
$keyVaultName = $eventGridEvent.data.VaultName

Write-Host "Key Vault Name: $keyVAultName"
Write-Host "Secret Name: $secretName"
Write-Host "Secret Version: $secretVersion"

#Rotate secret
Write-Host "Rotation started."
RotateSecret $keyVAultName $secretName $secretVersion
Write-Host "Secret Rotated Successfully"
