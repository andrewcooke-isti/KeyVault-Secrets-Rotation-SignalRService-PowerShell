# ADDED BY andrewcooke-isti

## Context

[This
article](https://docs.microsoft.com/en-gb/azure/key-vault/secrets/tutorial-rotation-dual?tabs=azure-cli)
includes (near the bottom) a [project
template](https://serverlesslibrary.net/sample/bc72c6c3-bd8f-4b08-89fb-c5720c1f997f)
for key rotation.  This repo is based on that template, modified for SignalR.

## Managed Identities

I did this work because I could not get managed identities to work for
SignalR.  However, that issue was eventually solved:

  * Edit the connection string to replace the secret key with `AuthType=aad`

  * Be very careful about what code versions you are using.  I used dotnet 3.1
    and, in the csproj file:

      <ItemGroup>
	<PackageReference Include="Microsoft.Azure.WebJobs.Extensions.SignalRService" Version="1.3.0" />
	<PackageReference Include="Microsoft.NET.Sdk.Functions" Version="3.0.12" />
	<PackageReference Include="Newtonsoft.Json" Version="12.0.2" />
      </ItemGroup>

## Permissions

If you don't want to use managed identities, but instead do key rotation using
this code, you need to follow the instructions in the article above and *also*
add the function app as owner of the resource group.  With that done you can
trigger an expiry and see rotation (eventually - it takes a few mins) in the
function app log stream.

# ORIGNAL DOCS - KeyVault-Secrets-Rotation-SignalRService-PowerShell

Functions regenerate individual key (alternating between two keys) in SignalRService and add regenerated key to Key Vault as new version of the same secret.

## Features

This project framework provides the following features:

* Rotation function for SignalRService key triggered by Event Grid (AKVSignalRServiceRotation)

* Rotation function for SignalRService key triggered by HTTP call (AKVSignalRServiceRotationHttp)

* ARM template for function deployment with secret deployment (optional)

* ARM template for adding SignalRService key to existing function with secret deployment (optional)

## Getting Started

Functions require following information stored in secret as tags:

* $secret.Tags["ValidityPeriodDays"] - number of days, it defines expiration date for new secret
* $secret.Tags["CredentialId"] - SignalRService credential id
* $secret.Tags["ProviderAddress"] - SignalRService Resource Id

You can create new secret with above tags and SignalRService key as value or add those tags to existing secret with SignalRService key. For automated rotation expiry date will also be required - key vault triggers 'SecretNearExpiry' event 30 days before expiry.

There are two available functions performing same rotation:

* AKVSignalRServiceRotation - event triggered function, performs SignalRService key rotation triggered by Key Vault events. In this setup Near Expiry event is used which is published 30 days before expiration
* AKVSignalRServiceRotationHttp - on-demand function with KeyVaultName and Secret name as parameters

Functions are using Function App identity to access Key Vault and existing secret "CredentialId" tag with SignalRService key id (key1/key2) and "ProviderAddress" with SignalRService Resource Id.

### Installation

ARM templates available:

* [Secrets rotation Azure Function and configuration deployment template](https://github.com/andrewcooke-isti/KeyVault-Secrets-Rotation-SignalRService-PowerShell/blob/main/ARM-Templates/Readme.md) - it creates and deploys function app and function code, creates necessary permissions, Key Vault event subscription for Near Expiry Event for individual secret (secret name can be provided as parameter), and deploys secret with Redis key (optional)
* [Add event subscription to existing Azure Function deployment template](https://github.com/andrewcooke-isti/KeyVault-Secrets-Rotation-SignalRService-PowerShell/blob/main/ARM-Templates/Readme.md) - function can be used for multiple services for rotation. This template creates new event subscription for secret and necessary permissions to existing function, and deploys secret with Redis key (optional)

## Demo

You can find example for Storage Account rotation in tutorial below:
[Automate the rotation of a secret for resources that have two sets of authentication credentials](https://docs.microsoft.com/azure/key-vault/secrets/tutorial-rotation-dual)

Youtube:
https://youtu.be/qcdVbXJ7e-4

**Project template information**:

This project was generated using [this](https://github.com/Azure/KeyVault-Secrets-Rotation-Template-PowerShell) template. You can find instructions [here](https://github.com/Azure/KeyVault-Secrets-Rotation-Template-PowerShell/blob/main/Project-Template-Instructions.md)
