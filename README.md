# User Behavior Analytics at DAJE Company
## Project Description
Behavioral analytics on a DAJE e-commerce dataset: Why does session drop-off run 3x higher than conversion? Initiated with SQL for exploration, expanded using Power BI &amp; Excel (z-tests) to uncover add-to-cart as the key split, testing 4 variables in a two-gate funnel
## Business Questions
- How does the conversion rate change across each stage of the shopping journey (session start -> add to cart -> checkout)?
- How do device, traffic source, price, and channel affect the buying decision - and is that effect real, or just random noise?
- What's really causing 9,167 sessions to never add a product to their cart?
- What's causing 4,630 sessions that added a product to cart to still not complete checkout?

## Dataset
- 108,584 interaction records
- 18,000 user sessions
- 6,806 synthetic users
- Diverse product categories and brands
- Extensive channel and region footprint
- Time period: 2026-01-01  -> 2026-05-01
<img width="775" height="243" alt="image" src="https://github.com/user-attachments/assets/ac82c06a-ccad-49b9-8e42-2d231ccab06b" />
<img width="542" height="246" alt="image" src="https://github.com/user-attachments/assets/06479166-a26a-4dc2-8676-d71a09799819" />

## Analysis Approach
- Clean and validate the data, then build the grouping fields (phan_khuc_KH customer segment, price_tier, speed_tier) in SQL Server 2022
- Analyze overall conversion across 4 context variables (device_type, Price_tier, traffic_source, channel)  - found weak signals, not enough to explain the gap
- Found the real behavioral split: add-to-cart (ATC) divides users into two almost opposite groups -> re-framed the funnel as Gate 1 (add to cart) and Gate 2 (checkout after adding to cart)
- Re-tested the same 4 variables at each gate using two-proportion z-tests, to avoid drawing conclusions from random coincidence
- Analyzed post-ATC behavior (the next action right after adding to cart) and return-visit purchase patterns

## Key Metrics & Measures
<img width="684" height="368" alt="image" src="https://github.com/user-attachments/assets/e9a2d0ea-0bed-4eeb-8a68-9b6aae016340" />
<img width="806" height="396" alt="image" src="https://github.com/user-attachments/assets/a2a208c2-f3da-47cc-8915-1e7885a1669e" />




## Key Findings 
All four context variables (device_type, Price_tier, traffic_source, channel) show weak, inconsistent signals when measured against the overall conversion rate  - not enough to explain why 76.6% of users drop off. But once the funnel is split by what people actually do (ATC turns out to be an almost absolute dividing line: with ATC -> 47.6% purchase, without ATC -> 0% purchase), those same four variables suddenly show clear, statistically significant effects  - and at the two gates, some of them even point in opposite directions.
<img width="542" height="232" alt="image" src="https://github.com/user-attachments/assets/2ed0fb9e-711e-4752-8158-4b1e61aae0ba" />
<img width="517" height="204" alt="image" src="https://github.com/user-attachments/assets/3272e93f-0547-4a40-9bf8-5227af24ce3c" />
<img width="1043" height="189" alt="image" src="https://github.com/user-attachments/assets/76cbaae7-880e-4533-977a-f246b89e6f1d" />



Answers to the Two Original Questions:
- 9,167 sessions with no ATC: on their own, the 4 context variables only produce a 3–5pp gap  - nowhere near enough to explain the 50.9% difference. The current data isn't enough to fully answer this question yet.
- 4,630 sessions that added to cart but didn't check out: when the 4 variables are re-tested at Gate 1/Gate 2, channel is the strongest and clearest signal (7.85pp, p<0.0001), centered on the App checkout experience vs Web/Mobile. 78.3% of these sessions still show engagement afterward (they don't leave right away) - this is the group with the clearest purchase intent, and the most realistic one to target.

## Recommendations
- Channel is the strongest effect at Gate 2 (7.85pp, p<0.0001): Improve the App checkout flow, especially right after ATC.
- High-priced items are easy to add to cart but harder to check out ( -3.55pp, p=0.006): Add decision-support tools for the high-price segment (comparisons, reviews, warranty/installment info) right after ATC.
- This segment already shows clear purchase intent - the most realistic lever to pull: Send abandoned-cart reminders (email/push notification, controlled incentives), targeted specifically at the 4,630 sessions that already added to cart.
- Direct and email traffic are consistently strong at both gates -  affiliate, paid_search, and social don't hold up as well: Measure marketing ROI by actual conversion rate, not traffic volume. Prioritize budget for Direct and Email, and re-evaluate spend on affiliate/paid_search/social.

## Limitations
- All findings are correlational, not confirmed as causal - a controlled A/B test is needed before rolling anything out broadly, especially for Gate 2 interventions.
- 65.24% of buyers had an ATC in a different, earlier session  - but that's a general pattern in buying behavior, not proof that this specific group of 4,630 sessions will come back. This exact group needs to be tracked further to confirm the real return rate.
- Most of the Gate 1 drop-off (9,167 sessions) still isn't fully explained by the 4 context variables available. Deeper analysis needs more in-session behavioral data (e.g., whether the product detail page was viewed, time on page before leaving).

## Project Structure
├── data/
├── sql/
├── Z-test_inputs.xlsx
├── User_Behavior_Analytics_at_DAJE_Company.pbix
├── user_behavior_dataset.csv
└── README.md

## Tools Used
- SQL Server 2022 (data cleaning, grouping)
- Power BI + DAX (measurement, visualization)
- SQL / Excel (running z-tests)

## Author
Tran Thi Ngoc Bich — Learning to turn raw data into meaningful insights
