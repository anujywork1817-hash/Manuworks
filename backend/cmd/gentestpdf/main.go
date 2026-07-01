package main

import (
	"fmt"
	"os"
	"github.com/yourusername/docassist/pkg/ocr"
)

func main() {
	complaintEnglish := `TO,
The Charity Commissioner, Maharashtra State, Mumbai
Public Trust Registration Office, Sasimira, Mumbai

AND

The Asst. Charity Commissioner,
Public Trust Registration Office, Thane

COMPLAINANTS:
1. Shri Narayan Kondu Thakare,
   504, C Wing, New Era, Yogidham, Gauripada, Kalyan (West)
   Former Employee, Shri Vajreshwari Yogini Devi Sansthan
   (Served 13 years as Accountant/Cashier and 20 years as Secretary,
    retired 31 May 2021, continued as In-charge Secretary for 2 additional years)

2. Shri Devidas A. Patil,
   Village Dugad, Taluka Bhiwandi, District Thane

SUBJECT:
Application requesting suspension and dismissal of trustees of Shri Vajreshwari
Yogini Devi Sansthan for violations of the Trust Deed, Maharashtra Public Trusts
Act 1950 and Income Tax laws; and for immediate appointment of an Administrator.

--- BACKGROUND ---

1. I, Shri Narayan Kondu Thakare, am a former employee of Shri Vajreshwari
   Yogini Devi Sansthan. Having worked 13 years as Accountant/Cashier and
   20 years as Secretary, and an additional 2 years post-retirement as
   In-charge Secretary, I am fully acquainted with the affairs of the temple
   and have its best interests at heart.

2. Shri Vajreshwari Yogini Devi Sansthan is a public charitable trust
   registered on 27/05/1952 under the Maharashtra Public Trusts Act 1950,
   with Registration No. A(192) Thane.

3. In Trustee Appointment Inquiry No. 12/2019, the Hon. District Court,
   Thane, by order dated 31/08/2019, appointed the following 5 trustees
   for a period of 5 years:
   1) Shri Madhukar Ramchandra Patkar        - Chairman
   2) Shri Dhanesh Hemendra Gosavi           - Hereditary Trustee
   3) Shri Milind Yashwant Chorghe           - Trustee
   4) Dr. Vivek Ramchandra Patil             - Trustee
   5) Shri Raju Shantaram Patil              - Trustee

4. The Board of Trustees took charge of the Sansthan on 13/09/2019.
   Accordingly, their 5-year term expired on 12/09/2024.

5. As per the Trust Deed (Clause 9(a)), trustees other than the hereditary
   trustee are to be appointed by the District Court for 5 years after
   consulting the Charity Commissioner. The Deed mandates that an
   application for new trustee appointment must be filed with the District
   Court at least 3 months before the term expires, i.e., by 12/06/2024.
   The current trustees failed to file any such application at the Sessions
   Court, Bhiwandi.

6. Instead, three trustees - Shri Madhukar Patkar, Shri Dhanesh Gosavi,
   and Shri Milind Chorghe - filed Miscellaneous Application No. 44/2024
   at the Sessions Court, Bhiwandi, seeking extension of their term. This
   is contrary to the Trust Deed, which contains no such provision. Since
   the Charity Commissioner has been made a Respondent in that application,
   we request that an objection be filed opposing the extension.

--- PROPERTY AND INCOME OF THE SANSTHAN ---

7. Shrimant Chimaji Appa donated 6 villages to Shri Vajreshwari Devi in
   1738 after the capture of Vasai Fort. The British Government continued
   the grant and issued Sanads for the following villages:
   - Moje Vajreshwari, Taluka Bhiwandi        - Sanad No. 77, dated 09/10/1884
   - Kaap Kaneri village                      - Sanad No. 74, dated 14/07/1864
   - Phene village                            - Sanad No. 73, dated 14/07/1864
   - Moje Bhinar, Taluka Vasai                - Sanad No. 87, dated 20/03/1885
   - Vadghar village                          - Sanad No. 85, dated 04/10/1884
   - Ambode village                           - Sanad No. 86, dated 10/03/1885
   Total land: approximately 3,000 acres (Inam Class 3).

8. Income sources include: land rent/lease from inam lands, donations,
   offerings, fixed deposit interest, and various religious contributions.
   Annual income is approximately Rs. 2 Crores.

--- ALLEGATIONS OF MISCONDUCT BY CURRENT TRUSTEES ---

ALLEGATION 12(1) - MISAPPROPRIATION OF GOLD AND SILVER ORNAMENTS:

When the current trustees took charge, an inventory of valuables was taken.
During an inspection on 07/07/2022 in the presence of the Inspector, the
following serious irregularities were found:
- Approximately 40 tolas (approx. 466 grams) of gold found missing.
- In a necklace of 19 gold figurines: 3 figurines were found to be silver.
- In a necklace of 17 gold figurines: 4 figurines were found to be silver.
- In a necklace of 18 gold figurines: 5 figurines were found to be silver.
- Out of gold beads (parachhuran): 19 beads and 1 nose ring found fake.
- The old treasury/safe of the Sansthan was not found.
- Gold plating was applied to the fake silver items to make them appear golden.
(Exhibit 5 - Valuation list dated 07/07/2022)

ALLEGATION 12(2) - LARGE SCALE SILVER MISSING:

As per valuation done on 19/12/2018, the Sansthan had 157.600 kg of silver.
But on 07/07/2022, the trustees could only account for 46.221 kg of silver.
The trustees made no effort to recover or account for the remaining silver
(approximately 111 kg), suggesting collusion with the hereditary trustee.
(Exhibit 6 - Valuation report dated 19/12/2018)

ALLEGATION 12(3) - CONTEMPT OF COURT AND TRUST DEED VIOLATION:

The trustees' term expired on 12/09/2024. As per the Trust Deed, they were
required to file an application at the District Court by 12/06/2024 (3 months
prior). They failed to do so, violating the Trust Deed and the court's order
for a fixed 5-year tenure. They continue to act as trustees without authority.

ALLEGATION 12(4) - ILLEGAL ACTS AFTER TERM EXPIRY:

After their term expired, trustees have no authority to make policy decisions.
However, they have:
- Transferred lands belonging to the Sansthan.
- Broken fixed deposits prematurely.
- Undertaken new construction work worth crores of rupees.
All of this was done without permission from the Charity Commissioner.

ALLEGATION 12(5) - MISAPPROPRIATION OF LAND ACQUISITION COMPENSATION:

Government acquired lands in Moje Bhinar and Ambode, Taluka Vasai, for the
Vadodara Expressway. Compensation was deposited in HDFC Bank, Thane branch.

Amounts received between 02/05/2024 and 20/06/2024 in HDFC Bank:
- 02/05/2024 from Charmkar Niwara                    Rs. 11,00,000
- 27/05/2024 from SDO Vasai                          Rs. 49,73,525
- 11/06/2024 from SDO Vasai                          Rs. 8,34,435
- 11/06/2024 from SDO Vasai                          Rs. 81,59,621
- 11/06/2024 from SDO Vasai                          Rs. 4,81,959
- 11/06/2024 from SDO Vasai                          Rs. 21,65,215
- 11/06/2024 from SDO Vasai                          Rs. 81,22,799
- 16/06/2024 from SDO Vasai                          Rs. 5,75,473
- 11/06/2024 from SDO Vasai                          Rs. 25,24,888
- 11/06/2024 from SDO Vasai                          Rs. 48,33,971
- 11/06/2024 from SDO Vasai                          Rs. 22,41,466
- 11/06/2024 from SDO Vasai                          Rs. 10,74,696
- 20/06/2024 from SDO Vasai                          Rs. 24,02,599
- 20/06/2024 from SDO Vasai                          Rs. 37,21,871
- 20/06/2024 from SDO Vasai                          Rs. 75,02,728
- 20/06/2024 from SDO Vasai                          Rs. 35,78,004
                                          TOTAL: Rs. 5,42,93,250

Illegal payments made from this account between 03/05/2024 and 21/06/2024:
- K.P. Enterprises Sahakar                           Rs. 16,22,000
- TPT Paid Laptop                                    Rs. 61,800
- Namrata Subhap Bobde                               Rs. 25,000
- Shri Manoj Prasad Bhat                             Rs. 10,000
- Swastik Enterprises (multiple payments)            Rs. 1,89,00,000
- Aditya Gyaneshwar Gurav (advocate fee)             Rs. 3,00,00,000
                                          TOTAL: Rs. 4,11,59,800

The compensation amount (Rs. 5,42,93,250), which represents permanent loss
of temple land, was required to be kept in Fixed Deposit under Section 35 of
the Maharashtra Public Trusts Act 1950, with only interest permitted to be
used after taking permission from the Charity Commissioner. This was not done.

ALLEGATION 12(6) - NEGLIGENCE IN PREVENTING FURTHER LOSS:

On 20/06/2024, I (Complainant No. 1) informed Chairman Shri Madhukar Patkar
and Trustee Shri Milind Chorghe about the misappropriation. They were slow to
investigate. On 21/06/2024, when they went to the bank, they found the facts
to be true. On the same morning, Rs. 3,00,00,000 had already been paid via
RTGS to advocate Shri Aditya Gurav as professional fees. Had trustees acted
with urgency, Rs. 3 Crores could have been saved. Due to the complaint raised
by me, a balance of Rs. 35,00,000 in the bank was saved. The total attempted
withdrawal was Rs. 12 Crores.

ALLEGATION 12(7) - DELAYED POLICE COMPLAINT, NO FIR REGISTERED:

Police complaint was filed late on 19/07/2024. No FIR has been registered
and no investigation conducted till date. The cheques were signed by Shri
Raju Shantaram Patil and Shri Milind Yashwant Chorghe.
(Exhibit 9 - Cheque xerox copies)

ALLEGATION 12(8) - ILLEGAL DEMOLITION AND SUBSTANDARD CONSTRUCTION:

After term expiry, trustees Madhukar Patkar, Dhanesh Gosavi, and Milind
Chorghe conspired to:
- Demolish the temple stage and rebuild it in a smaller size.
- Demolish the old stone bungalow of the hereditary trustee (which was
  structurally sound for 100+ more years) instead of just repairing the
  roof - causing unnecessary loss.
- Demolish the protective wall of the temple car park and rebuild it
  shoddily - it collapsed in the rain within a month, wasting all expense.
- Temple painting, electrical work, railings, and the temple kitchen
  (Naivedya room) needing urgent repairs were NOT done during the tenure.

ALLEGATION 12(9) - TDS NOT DEDUCTED OR DEPOSITED:

In FY 2024-25:
- TDS at 1% under Section 194C not deducted from contractor bills.
- TDS at 10% under Section 194J not deducted from fees paid to lawyers
  and architects.
- These amounts were not deposited with the Income Tax Department.
Future penalties including TDS, interest, and late fees are likely to
exceed Rs. 52,00,000. Trustees who signed the cheques should be held
personally liable.

ALLEGATION 12(10) and 12(11) - PREMATURE BREAKING OF FIXED DEPOSITS:

Fixed deposits were made per Charity Commissioner's orders in the names of:
Corpus Fund, Educational Fund, Medical Fund, Trust Fund, Charity Fund,
Development Fund, and Donation Reserve Fund.

These FDs were broken prematurely before maturity by trustees Madhukar
Patkar, Dhanesh Gosavi, and Milind Chorghe (by signing on them), under the
pretext of "development work":

Date         Bank           Amount
18/06/2024   Canara Bank    Rs. 38,92,408
18/06/2024   Canara Bank    Rs. 40,63,022
15/10/2024   Canara Bank    Rs. 59,76,801
11/11/2024   Canara Bank    Rs. 34,81,902
03/01/2025   Canara Bank    Rs. 1,20,76,455
09/06/2025   Canara Bank    Rs. 1,24,26,342
             DTICDI Bank    Rs. 38,43,898
             TOTAL:         Rs. 4,69,74,718.71

Under Section 35 of the Maharashtra Public Trusts Act 1950, FDs made by
order of the Charity Commissioner cannot be broken without the Commissioner's
prior permission. These trustees did not have such permission. The Sansthan's
annual income is approximately Rs. 2 Crores. Development expenditure of
Rs. 70-80 Lakhs per year could be planned. Spending crores in this manner
will take the next board of trustees at least 20 years to recover.

ALLEGATION 12(13) - MASSIVE LOSS OF INAM LAND:

Land in Vasai Taluka in the name of the deity (Inam Class 3):

Village    Account   Area When Trustees      Reduction         Current Area
           No.       Took Charge (H.R.)      (H.R.)            (H.R.)
Bhinar     124       391-73-30               372-72-00         19-01-30
Vadghar    143       288-95-73               276-04-73         12-91-00
Ambode     18        7-22-10                 112-08-01         7-80-90 (approx)

TOTAL land when trustees took charge: 800-57-94 H.R.
TOTAL land remaining in deity's name today: Only 39-73-20 H.R.

Additionally, Inam Class 3 entries have been removed from the 7/12 extracts.
In the last 55 years, the Sansthan has never suffered such massive land loss
under any board of trustees.

ALLEGATION 12(14) - TREES CUT WITHOUT FOREST PERMISSION:

The board of trustees cut down 30-50 year old trees (mango, rainee, jackfruit,
jamun, and umbar) inside the temple premises and surrounding area, trees that
were not obstructing any development work, without obtaining permission from
the Forest Department.

ALLEGATION 12(15) - FAILURE TO FILE 10BD AND BE FORMS FOR DONORS:

The Sansthan has an 80G certificate. In FY 2024-25, trustees failed to submit
donor information to the Income Tax Department and failed to obtain Form 10BD
and BE certificates for major donors before May 2025. This deprived donors of
their legitimate tax exemption, amounting to fraud against the devotees. Such
conduct will harm the Sansthan's future donation income.

--- PRAYERS ---

In light of the above serious violations, the Complainants most respectfully
pray that this Hon'ble Office may be pleased to:

1. File an objection at the Sessions Court, Bhiwandi against Miscellaneous
   Application No. 44/2024 filed by the trustees seeking an extension of
   their tenure beyond the 5-year limit.

2. Initiate the process for fresh appointment of new trustees as per the
   Trust Deed without further delay, and file an application before the
   Hon. Court for the same.

3. Immediately suspend the current trustees and freeze their powers in view
   of the damages caused as enumerated above.

4. Issue directions prohibiting trustees from making payments to contractors
   or any other party (other than daily expenses) without prior permission
   from the Charity Commissioner or Asst. Charity Commissioner.

5. Take suo motu cognizance of this complaint and initiate proceedings for
   the dismissal of the trustees.

6. Hold the trustees responsible under Section 35 of the Maharashtra Public
   Trusts Act 1950 and Income Tax laws for the losses caused due to their
   negligence, irresponsibility, and malafide conduct. Direct a competent
   authority to conduct an inquiry and recover the losses.

We, the complainants, hereby state and affirm that the information given
above is true and correct to the best of our knowledge and belief.

Signed at Vajreshwari on this 9th day of September 2025.

1. Shri Narayan Kondu Thakare         2. Shri Devidas Aatma Rakhsha Patil
   Mobile: 9421630686                    Mobile: 8793852341
   Former Employee                       Devotee and Well-wisher
   Shri Vajreshwari Yogini Devi Sansthan

Copies for information and appropriate action:
1. Hon. Shri Sureshji Mhatre - Member of Parliament, Bhiwandi Lok Sabha Constituency`

	pdfBytes, err := ocr.CreatePDF(complaintEnglish)
	if err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
	if err := os.WriteFile("vajreshwari_complaint_english.pdf", pdfBytes, 0644); err != nil {
		fmt.Fprintf(os.Stderr, "ERROR: %v\n", err)
		os.Exit(1)
	}
	fmt.Printf("Created vajreshwari_complaint_english.pdf (%d bytes)\n", len(pdfBytes))
}
