length ethernet packet: (46 - 1500 bytes) + 14 + FCS = 60-1514 [byte] + FCS

    +----+----+------+------+-----+
    | DA | SA | Type | Data | FCS |
    +----+----+------+------+-----+
              ^^^^^^^^

    DA      Destination MAC Address (6 bytes)
    SA      Source MAC Address      (6 bytes)
    Type    Protocol Type           (2 bytes: >= 0x0600 or 1536 decimal)  <---
    Data    Protocol Data           (46 - 1500 bytes)
    FCS     Frame Checksum          (4 bytes)

