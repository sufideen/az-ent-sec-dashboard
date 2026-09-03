// ============================================================================
// Module: workbook.bicep
// Purpose: Deploy an Azure Workbook (shared, Sentinel-category) backed by a
// serialized workbook JSON definition (see /workbooks/*.json). The caller
// loads the JSON with loadTextContent() and passes it in as workbookJson.
// ============================================================================

@description('A GUID that uniquely and stably identifies this workbook. Reuse the same GUID across deployments to update-in-place rather than duplicate.')
param workbookId string

@description('Display name shown in the Azure Portal / Sentinel Workbooks gallery.')
param displayName string

@description('Raw workbook JSON (the *contents* of the workbook file), typically produced via loadTextContent(\'../workbooks/xyz.json\').')
param workbookJson string

@description('Resource ID of the Log Analytics Workspace the workbook queries by default.')
param sourceId string

@description('Azure region for the workbook resource.')
param location string

@description('Category used to group the workbook in the gallery. \'sentinel\' surfaces it under Microsoft Sentinel > Workbooks.')
param category string = 'sentinel'

@description('Tags applied to the resource.')
param tags object = {}

resource workbook 'Microsoft.Insights/workbooks@2023-06-01' = {
  name: workbookId
  location: location
  tags: tags
  kind: 'shared'
  properties: {
    displayName: displayName
    serializedData: workbookJson
    version: '1.0'
    sourceId: sourceId
    category: category
  }
}

output workbookResourceId string = workbook.id
output workbookName string = workbook.name
