# ========================================================================
# TEST-KAFKA-FIX.ps1 - Verify Kafka Connectivity Fix
# ========================================================================
# This script tests if Kafka event flow is working after the fix
# Expected: Order created → Kafka event published → Inventory reserved
# ========================================================================

$RG = "microservices-rg"
$GW = 'https://gateway.ashyplant-ea07b56b.eastasia.azurecontainerapps.io'

Write-Host "=======================================" -ForegroundColor Cyan
Write-Host "KAFKA CONNECTIVITY FIX VERIFICATION" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan

# Check if services are running
Write-Host "`n[1/5] Checking service status..." -ForegroundColor Yellow
az containerapp list --resource-group $RG --query "[].{Name:name, Status:properties.runningStatus}" --output table

# Test gateway connectivity
Write-Host "`n[2/5] Testing gateway connectivity..." -ForegroundColor Yellow
$healthResp = curl.exe --max-time 10 -s "$GW/actuator/health"
if ($healthResp -match "UP") {
    Write-Host "✓ Gateway is UP" -ForegroundColor Green
} else {
    Write-Host "✗ Gateway returned: $healthResp" -ForegroundColor Red
}

# Create test order
Write-Host "`n[3/5] Creating order with Kafka event..." -ForegroundColor Yellow
$orderId = "KAFKA-TEST-$(Get-Date -Format 'HHmmss')"
$payload = "{`"orderId`":`"$orderId`",`"sku`":`"SKU-TEST`",`"quantity`":3}"

Write-Host "Order ID: $orderId"
$createResp = curl.exe -X POST "$GW/orders" -H "Content-Type: application/json" -d $payload --max-time 30 -s -w "`n%{http_code}"
Write-Host $createResp

# Wait for event processing
Write-Host "`n[4/5] Waiting for Kafka event processing (15 seconds)..." -ForegroundColor Yellow
1..15 | ForEach-Object { 
    Write-Host "." -NoNewline
    Start-Sleep -Seconds 1 
}
Write-Host ""

# Check order status
Write-Host "`n[5/5] Checking order status after event processing..." -ForegroundColor Yellow
$statusResp = curl.exe "$GW/orders/$orderId" --max-time 30 -s
$status = $statusResp | ConvertFrom-Json

Write-Host "Order Details:"
Write-Host "  ID: $($status.orderId)"
Write-Host "  Status: $($status.status)"
Write-Host "  SKU: $($status.sku)"
Write-Host "  Quantity: $($status.quantity)"

# Verify result
if ($status.status -eq "INVENTORY_RESERVED") {
    Write-Host "`n✓✓✓ SUCCESS! Kafka is working correctly! ✓✓✓" -ForegroundColor Green
    Write-Host "Order flow: CREATED → (Kafka event) → INVENTORY_RESERVED" -ForegroundColor Green
} elseif ($status.status -eq "CREATED") {
    Write-Host "`n✗ Order still in CREATED status - Kafka events not flowing" -ForegroundColor Red
    Write-Host "Debug: Check service logs:" -ForegroundColor Yellow
    Write-Host "  az containerapp logs show --name order-service --resource-group $RG --tail 100" -ForegroundColor DarkYellow
} else {
    Write-Host "`n? Unexpected status: $($status.status)" -ForegroundColor Yellow
}

# Show service logs snippet
Write-Host "`nRecent Kafka errors (if any):" -ForegroundColor Cyan
az containerapp logs show --name order-service --resource-group $RG --tail 30 | `
    Select-String "kafka|bootstrap|Bootstrap|timeout|connection" -Context 1 | `
    Select-Object -First 10

Write-Host "`n=======================================" -ForegroundColor Cyan
Write-Host "Test completed" -ForegroundColor Cyan
Write-Host "=======================================" -ForegroundColor Cyan
