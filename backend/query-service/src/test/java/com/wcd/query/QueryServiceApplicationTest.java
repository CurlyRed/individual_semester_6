package com.wcd.query;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class QueryServiceApplicationTest {

    @Test
    void applicationClassExists() {
        // Verify the application class exists and can be instantiated
        assertDoesNotThrow(() -> {
            Class<?> clazz = Class.forName("com.wcd.query.QueryServiceApplication");
            assertNotNull(clazz);
        });
    }

    @Test
    void mainMethodExists() throws NoSuchMethodException {
        // Verify main method exists with correct signature
        Class<?> clazz = QueryServiceApplication.class;
        assertNotNull(clazz.getMethod("main", String[].class));
    }
}
