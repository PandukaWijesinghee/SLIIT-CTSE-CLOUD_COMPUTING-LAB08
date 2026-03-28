package com.example.gateway;

import java.util.Map;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class GatewayInfoController {

    @GetMapping("/")
    public Map<String, Object> root() {
        return Map.of(
                "service", "api-gateway",
                "status", "UP",
                "message", "Gateway is running. Use /orders/**, /inventory/**, /notify/**",
                "health", "/actuator/health"
        );
    }
}
