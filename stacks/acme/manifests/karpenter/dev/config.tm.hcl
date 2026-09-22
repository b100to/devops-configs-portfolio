# =============================================================================
# Dev Environment Karpenter NodePool Configuration
# =============================================================================
# Instance Type Reference (ap-northeast-2):
# +--------------+------+--------+------------------+----------------------+
# | Type         | vCPU | Memory | On-Demand ($/hr) | Spot ($/hr, savings) |
# +--------------+------+--------+------------------+----------------------+
# | r5a.xlarge   |  4   |  32GB  |     $0.226       |  ~$0.10 (56%, <5%)   |
# | t3.xlarge    |  4   |  16GB  |     $0.166       |  ~$0.05 (68%, <5%)   |
# | m6i.xlarge   |  4   |  16GB  |     $0.192       |  ~$0.06 (66%, >20%)  |
# | r6i.xlarge   |  4   |  32GB  |     $0.252       |  ~$0.08 (60%, >20%)  |
# +--------------+------+--------+------------------+----------------------+
#                                              savings% = spot discount, ()% = interruption rate
#
# Current Selection: 1 NodePool (t3.2xlarge 단일 노드)
# - base (t3.2xlarge): 8 vCPU, 32GB → r5a.xlarge 대비 CPU 2배, 비용 동일 수준
# - JVM cold start CPU spike 대응 위해 r5a.xlarge(4 vCPU) → t3.2xlarge(8 vCPU) 전환 (2026-03-11)
# - overflow NodePool 불필요 (CPU 여유 충분)
# =============================================================================

globals {
  environment    = "dev"
  account_id     = "111111111111"
  instance_types = ["t3.2xlarge"]
  cpu_limit      = "8"
}
