# BackEndServices

## Build JARs

Run these from the BackEndServices root.

### PowerShell (Windows)

```powershell
Push-Location inventory-service
mvn clean package
Pop-Location

Push-Location order-service
mvn clean package
Pop-Location

Push-Location payment-service
mvn clean package
Pop-Location
```

### Bash (macOS/Linux)

```bash
( cd inventory-service && mvn clean package )
( cd order-service && mvn clean package )
( cd payment-service && mvn clean package )
```

## Run with Docker Compose

From the BackEndServices root:

```bash
docker compose up --build
```

Stop containers:

```bash
docker compose down
```
