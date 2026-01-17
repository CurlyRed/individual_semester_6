package com.wcd.projector;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.*;

class ProjectorServiceApplicationTest {

    @Test
    void applicationClassExists() {
        // Verify the application class exists
        assertDoesNotThrow(() -> {
            Class<?> clazz = Class.forName("com.wcd.projector.ProjectorServiceApplication");
            assertNotNull(clazz);
        });
    }

    @Test
    void mainMethodExists() throws NoSuchMethodException {
        // Verify main method exists with correct signature
        Class<?> clazz = ProjectorServiceApplication.class;
        assertNotNull(clazz.getMethod("main", String[].class));
    }
}
