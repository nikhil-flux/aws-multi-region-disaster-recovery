<b>🎯 Project Overview<b>
This project demonstrates a multi-region disaster recovery (DR) setup on AWS with infrastructure-as-code using Terraform. It creates a highly available web application that spans two geographic regions (us-east-1 and us-west-2), ensuring business continuity if one region fails.
<h1>Key Features<h1>
	•	✅ Two independent regions with identical infrastructure
	•	✅ Automatic failover detection via health check script
	•	✅ Data replication across regions using S3
	•	✅ Infrastructure as Code (Terraform)
	•	✅ Load balancing within each region
	•	✅ Multi-AZ redundancy within each region
DR Strategy: Cold Standby
This project implements a cold standby disaster recovery pattern:
	•	Primary Region (us-east-1): Actively serving production traffic
	•	Secondary Region (us-west-2): Idle, ready to take over if primary fails
	•	RTO (Recovery Time Objective): ~5-10 minutes (manual failover)
	•	RPO (Recovery Point Objective): ~minutes (depends on data sync interval)
