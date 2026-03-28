# Kafka Fix & Order Testing Troubleshooting

## Issue Encountered

**POST /orders returns HTTP 400 Bad Request**

Your JSON payload:
```json
{"orderId":"TEST-1","sku":"SKU-01","quantity":2}
```

The OrderRequest model expects:
- `orderId`: String (not blank)
- `sku`: String (not blank)  
- `quantity`: int (minimum 1)

✓ Your payload is valid

---

## Root Cause Analysis

The HTTP 400 is likely due to **curl.exe JSON escaping in PowerShell**. When you mix single quotes and backticks with nested JSON, special characters can get mangled.

---

## Solution: Use JSON File Method (Recommended)

### Step 1: Create ordered payload file

Save this to `order-test.json`:
```json
{
  "orderId": "KAFKA-TEST-001", 
  "sku": "SKU-KAFKAFIX",
  "quantity": 3
}
```

### Step 2: Test with file-based payload
```powershell
$GW = 'https://gateway.ashyplant-ea07b56b.eastasia.azurecontainerapps.io'

curl.exe -X POST "$GW/orders" `
  -H "Content-Type: application/json" `
  --data-binary "@order-test.json" `
  --max-time 30 -s
```

This avoids all escaping issues.

---

## Alternative: PowerShell Native Method

```powershell
$GW = 'https://gateway.ashyplant-ea07b56b.eastasia.azurecontainerapps.io'

$payload = @{
    orderId = "KAFKA-TEST-002"
    sku     = "SKU-KAFKAFIX"
    quantity = 3
} | ConvertTo-Json -Compress

# Using Invoke-RestMethod (PowerShell native)
$response = Invoke-RestMethod -Uri "$GW/orders" `
    -Method Post `
    -ContentType "application/json" `
    -Body $payload

$response
```

This is more reliable than curl.exe + JSON in PowerShell.

---

## Testing Sequence After Kafka Fix

### 1. Create Order
```powershell
# Create order
$response = Invoke-RestMethod -Uri "$GW/orders" `
    -Method Post `
    -ContentType "application/json" `
    -Body (@{orderId="KAFKA-001"; sku="SKU-001"; quantity=2} | ConvertTo-Json -Compress)

$response
# Expected: {"orderId":"KAFKA-001","status":"CREATED","message":"Order accepted and event published"}
```

### 2. Wait for Kafka Event Processing
```powershell
Write-Host "Waiting 15 seconds for Kafka events..."
Start-Sleep -Seconds 15
```

### 3. Check Order Status
```powershell
# Check status - should transition to INVENTORY_RESERVED if Kafka is working
$status = Invoke-RestMethod -Uri "$GW/orders/KAFKA-001" -Method Get
$status

# Expected if Kafka working: {"orderId":"KAFKA-001","status":"INVENTORY_RESERVED","sku":"SKU-001","quantity":2}
# Expected if Kafka not working: {"orderId":"KAFKA-001","status":"CREATED",...}
```

### 4. Check Service Logs
```powershell
# If status is still CREATED, check why Kafka event wasn't processed
az containerapp logs show --name order-service --resource-group microservices-rg --tail 50
```

---

## Quick Diagnostic Commands

```powershell
# 1. Check all services running
az containerapp list --resource-group microservices-rg --output table

# 2. Check gateway FQDN
az containerapp show --name gateway --resource-group microservices-rg `
    --query properties.configuration.ingress.fqdn -o tsv

# 3. Test gateway health
$GW = 'https://gateway.ashyplant-ea07b56b.eastasia.azurecontainerapps.io'
Invoke-RestMethod -Uri "$GW/actuator/health"

# 4. Verify Kafka config
az containerapp show --name kafka --resource-group microservices-rg `
    --query 'properties.template.containers[0].env[] | select(name == "KAFKA_ADVERTISED_LISTENERS")'

# 5. Check order service bootstrap
az containerapp show --name order-service --resource-group microservices-rg `
    --query 'properties.template.containers[0].env[] | select(name == "SPRING_KAFKA_BOOTSTRAP_SERVERS")'
```

---

## Most Common Issues & Fixes

### Issue #1: HTTP 400 on POST
**Cause**: Malformed JSON (escaping issues)
**Fix**: Use `--data-binary @file.json` or PowerShell `Invoke-RestMethod` native method

### Issue #2: HTTP Connection Timeout
**Cause**: Gateway not responding
**Fix**: 
```powershell
# Restart gateway
az containerapp update --name gateway --resource-group microservices-rg --image sliitmicro86578.azurecr.io/gateway:v3
Start-Sleep -Seconds 30
# Retry request
```

### Issue #3: Order Status Still "CREATED" After 15 seconds
**Cause**: Kafka not connecting or events not flowing
**Fix**: Verify Kafka fix was applied with:
```powershell
# Check Kafka advertised listeners
az containerapp show --name kafka --resource-group microservices-rg `
    --query 'properties.template.containers[0].env[] | select(name == "KAFKA_ADVERTISED_LISTENERS") | .[0].value'

# Should output: PLAINTEXT://kafka:9092
```

### Issue #4: "UNKNOWN" Status
**Cause**: Order was never created (POST failed)
**Fix**: Fix the POST request first using file method above

---

## Next Steps

1. **Try the file-based JSON method** - create `order-test.json` and use `--data-binary @order-test.json`
2. **If still getting 400**: Check order service logs for specific validation error
3. **If POST succeeds (returns 202)**: Wait 15 seconds and check status transition
4. **If status doesn't transition**: Kafka connectivity issue - run diagnostics #4 above

Let me know the exact error from the order service logs and I can help pinpoint the issue.
