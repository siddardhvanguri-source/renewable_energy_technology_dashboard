CREATE TABLE `controllerCommands` (
	`id` bigint AUTO_INCREMENT NOT NULL,
	`deviceId` int NOT NULL,
	`userId` int,
	`command` enum('stop','resume','sync') NOT NULL,
	`payload` text NOT NULL,
	`status` enum('QUEUED','SENT','ACKNOWLEDGED','FAILED') NOT NULL DEFAULT 'QUEUED',
	`createdAtMs` bigint NOT NULL,
	`acknowledgedAtMs` bigint,
	CONSTRAINT `controllerCommands_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE TABLE `controllerSettings` (
	`id` int AUTO_INCREMENT NOT NULL,
	`deviceId` int NOT NULL,
	`sampleRateHz` int NOT NULL DEFAULT 20,
	`isrPeriodUs` int NOT NULL DEFAULT 10,
	`websocketPort` int NOT NULL DEFAULT 81,
	`activeScenario` varchar(16) NOT NULL DEFAULT 'S5',
	`autoStopEnabled` boolean NOT NULL DEFAULT true,
	`updatedAtMs` bigint NOT NULL,
	CONSTRAINT `controllerSettings_id` PRIMARY KEY(`id`),
	CONSTRAINT `controllerSettings_deviceId_unique` UNIQUE(`deviceId`)
);
--> statement-breakpoint
CREATE TABLE `devices` (
	`id` int AUTO_INCREMENT NOT NULL,
	`deviceKey` varchar(64) NOT NULL,
	`name` varchar(128) NOT NULL,
	`firmware` varchar(64) NOT NULL DEFAULT 'unknown',
	`status` enum('LIVE','DEMO','OFFLINE') NOT NULL DEFAULT 'DEMO',
	`websocketUrl` varchar(255),
	`lastSeenMs` bigint,
	`createdAt` timestamp NOT NULL DEFAULT (now()),
	`updatedAt` timestamp NOT NULL DEFAULT (now()) ON UPDATE CURRENT_TIMESTAMP,
	CONSTRAINT `devices_id` PRIMARY KEY(`id`),
	CONSTRAINT `devices_deviceKey_unique` UNIQUE(`deviceKey`)
);
--> statement-breakpoint
CREATE TABLE `scenarios` (
	`id` int AUTO_INCREMENT NOT NULL,
	`code` varchar(16) NOT NULL,
	`name` varchar(128) NOT NULL,
	`description` text NOT NULL,
	`target` varchar(128) NOT NULL,
	`metric` varchar(64) NOT NULL,
	`result` varchar(64) NOT NULL,
	`status` enum('READY','RUNNING','COMPLETE') NOT NULL DEFAULT 'READY',
	`updatedAtMs` bigint NOT NULL,
	CONSTRAINT `scenarios_id` PRIMARY KEY(`id`),
	CONSTRAINT `scenarios_code_unique` UNIQUE(`code`)
);
--> statement-breakpoint
CREATE TABLE `telemetrySamples` (
	`id` bigint AUTO_INCREMENT NOT NULL,
	`deviceId` int NOT NULL,
	`timestampMs` bigint NOT NULL,
	`vPv` double NOT NULL,
	`iPv` double NOT NULL,
	`pPv` double NOT NULL,
	`vMp` double NOT NULL,
	`iPh` double NOT NULL,
	`duty` double NOT NULL,
	`efficiency` double NOT NULL DEFAULT 96.8,
	`scenarioCode` varchar(16) NOT NULL DEFAULT 'S5',
	CONSTRAINT `telemetrySamples_id` PRIMARY KEY(`id`)
);
--> statement-breakpoint
CREATE INDEX `commands_device_time_idx` ON `controllerCommands` (`deviceId`,`createdAtMs`);--> statement-breakpoint
CREATE INDEX `devices_status_idx` ON `devices` (`status`);--> statement-breakpoint
CREATE INDEX `telemetry_device_time_idx` ON `telemetrySamples` (`deviceId`,`timestampMs`);--> statement-breakpoint
CREATE INDEX `telemetry_scenario_idx` ON `telemetrySamples` (`scenarioCode`);