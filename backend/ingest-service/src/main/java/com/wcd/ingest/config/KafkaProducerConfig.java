package com.wcd.ingest.config;

import com.wcd.common.events.GameActionV1;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.kafka.core.KafkaTemplate;
import org.springframework.kafka.core.ProducerFactory;

@Configuration
public class KafkaProducerConfig {

    @Bean
    public KafkaTemplate<String, GameActionV1> kafkaTemplate(ProducerFactory<String, GameActionV1> producerFactory) {
        return new KafkaTemplate<>(producerFactory);
    }
}
