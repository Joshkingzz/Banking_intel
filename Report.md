# 🏦 Banking Transaction Analysis Report

## 📘 Project Overview

This analysis uncovers customer behavior, transaction trends, revenue drivers, and product alignment using a banking dataset. The goal is to provide data-driven insights that help banks understand customer segmentation, channel usage, and transaction performance.

> **Tools Used**: SQL Server (data manipulation, joins, window functions, correlation), Power BI (recommended for visualization)

![Image](https://github.com/user-attachments/assets/44724e96-3df5-40fe-9354-8dc0c9e2fa2f)
![Image](https://github.com/user-attachments/assets/9a52cacb-e914-4417-9137-acfd64a519c9)
![Image](https://github.com/user-attachments/assets/fa9daba3-a784-4e4d-9c4a-01d02bebcbe2)
![Image](https://github.com/user-attachments/assets/67376fad-2f65-461b-8769-0038e40dd360)
![Image](https://github.com/user-attachments/assets/42cabb9a-2a78-47db-b45c-6e1050920d33)

---

## 🧰 Methodology

The project uses normalized relational data across the following tables:
```
select * from fact as j
inner join branch as a on j.branchcityid = a.branchcityid
inner join category as b on j.productcategoryid = b.productcategoryid
inner join subcategory as c on j.productsubcategoryid = c.productsubcategoryid
inner join channel as d on j.channelid = d.channelid
inner join currency as e on j.currencyid = e.currencyid
inner join [date] as f on j.transactiondateid = f.transactiondateid
inner join offer as g on j.recommendedofferid = g.recommendedofferid
inner join segment as h on j.customersegmentid = h.customersegmentid
inner join txn_type as i on j.transactiontypeid = i.transactiontypeid;
```

* **fact**: Contains transactional and customer-specific financial records
* **dimension tables**: `branch`, `category`, `subcategory`, `channel`, `currency`, `date`, `offer`, `segment`, `txn_type`

### Key Data Preparation Steps

```
select * into fact_copy from fact;
select * into branch_copy from branch;
select * into category_copy from category;
select * into subcategory_copy from subcategory;
select * into channel_copy from channel;
select * into currency_copy from currency;
select * into date_copy from [date];
select * into offer_copy from offer;
select * into segment_copy from segment;
select * into txn_type_copy from txn_type;
```
```
alter table fact
add fee_to_amt float, 
    fee_to_income float,
    amt float,
    accumulated_fees float,
    fees float,
    income float;

alter table fact
drop column 
    
    amt ,
    accumulated_fees,
    fees,
    income



update Fact 
set Amt = Amount * 0.88
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'USD'

update Fact 
set Amt = Amount
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'EUR'

update Fact 
set Accumulated_fees = creditcardfees + insurancefees + latepaymentamount
from Fact

update Fact 
set Fees = accumulated_fees * 0.88
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'USD'

update Fact 
set Fees = accumulated_fees
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'EUR'

update Fact 
set Income = MonthlyIncome * 0.88
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'USD'

update Fact 
set income = MonthlyIncome
from Fact
inner join currency on Fact.currencyid = Currency.currencyid
where Currency.Currency = 'EUR'

update fact
set fee_to_amt = fees/amt

update fact
set fee_to_income = fees/income




--dropping unwanted columns
Alter table fact
drop column monthlyincome, Amount, creditcardfees, accumulated_fees, insurancefees, latepaymentamount
```

1. **Table duplication** 
2. **Currency normalization**: Standardized all values to EUR using conversion rate (USD \* 0.88).
3. **Feature engineering**:

   * `fees` = Sum of credit card, insurance, and late payment fees.
   * `fee_to_amt` and `fee_to_income`: Measures customer cost burden.
4. **Column cleanup** to drop unnecessary fields after transformations.

---

## 📊 A. Customer Insight & Segmentation

### 1. Most Transaction-Active Customer Segment
```
select h.CustomerSegment, count(j.transactionID) as Transaction_Volume from fact as j 
inner join segment as h on j.customersegmentid = h.customersegmentid
group by h.customersegment
order by Transaction_Volume desc
```
![Image](https://github.com/user-attachments/assets/f05ae801-b917-49ee-a723-04fa5274a259)


* **The Middle Income** showed the highest transaction volume, followed by **High Income** and **Low Income** segments.
* Insight: The middle Income segment dominates usage frequency, suggesting high engagement from individual users.

### 2. Most Popular Financial Products by Segment
```
with popular_product as (
    select 
        h.CustomerSegment as Customer_segment,
        b.ProductCategory as product_category,
        count(j.TransactionID) as Transaction_volume,
        row_number() over ( partition by h.customersegment order by count(*) desc
        ) as rank
    from fact as j
    inner join category as b on j.productcategoryid = b.productcategoryid
    inner join segment as h on j.customersegmentid = h.customersegmentid
    group by h.CustomerSegment, b.ProductCategory
)
select 
    Customer_segment, product_category, Transaction_Volume
from popular_product
where rank = 1
order by Customer_segment
```
![Image](https://github.com/user-attachments/assets/97830026-e219-456a-a4ed-15153d59faef)

* Product preferences varied:

  * **The Middle Income Segment** → Credit Cards
  * **The High Income Segment** → Savings Account
  * **The Low Income Segment** → Savings Account
* Insight: Tailored product offerings per segment improve alignment and engagement.

### 3. Correlation Between Credit Score, Fees, and Frequency
```
with score_metrics as (
    select 
        CustomerScore,
        count(*) as transaction_frequency,
        sum(coalesce(creditcardfees, 0) + coalesce(insurancefees, 0) + coalesce(latepaymentamount, 0)) as total_fees
    from fact
    group by CustomerScore
),
correlation_calc as (
    select 
        -- correlation between CustomerScore and transaction frequency
        (count(*) * sum(CAST(CustomerScore AS bigint) * transaction_frequency) - 
         sum(CAST(CustomerScore AS bigint)) * sum(transaction_frequency)) /
        nullif(sqrt(
            (count(*) * sum(CAST(CustomerScore AS bigint) * CAST(CustomerScore AS bigint)) - power(sum(CAST(CustomerScore AS bigint)), 2)) *
            (count(*) * sum(CAST(transaction_frequency AS bigint) * CAST(transaction_frequency AS bigint)) - power(sum(CAST(transaction_frequency AS bigint)), 2))
        ), 0) as corr_Txn_Frequency,
        -- correlation between CustomerScore and total fees
        (count(*) * sum(CAST(CustomerScore AS bigint) * total_fees) - 
         sum(CAST(CustomerScore AS bigint)) * sum(total_fees)) /
        nullif(sqrt(
            (count(*) * sum(CAST(CustomerScore AS bigint) * CAST(CustomerScore AS bigint)) - power(sum(CAST(CustomerScore AS bigint)), 2)) *
            (count(*) * sum(CAST(total_fees AS float) * CAST(total_fees AS float)) - power(sum(CAST(total_fees AS float)), 2))
        ), 0) as corr_Accumulated_fees
    from score_metrics
)
select 
    corr_Txn_Frequency,
    corr_Accumulated_fees
from correlation_calc;
```
![Image](https://github.com/user-attachments/assets/ac42aa48-3e2b-4c64-9968-eda4ee76474e)
![Image](https://github.com/user-attachments/assets/2dc8b6b9-b7d8-4803-85de-e58b1241da79)

* Calculated **Pearson correlation**:

  * There was no correlation

---

## 💳 B. Transaction Behavior Analysis

### 1. Dominant Transaction Types
```
select i.TransactionType, count(J.TransactionID) as Transaction_volume from 
fact as j
inner join txn_type as i on j.transactiontypeid = i.transactiontypeid
group by i.TransactionType
order by Transaction_volume desc
```
![Image](https://github.com/user-attachments/assets/23b12f04-0ebe-48d6-a87c-ee244f87222b)

```
select i.TransactionType, sum(Amt) as Transaction_Amount from 
fact as j
inner join txn_type as i on j.transactiontypeid = i.transactiontypeid
group by i.TransactionType
order by Transaction_Amount desc
```
![Image](https://github.com/user-attachments/assets/aec28c21-1662-44bf-9da3-e21132d951b8)

* **Withdrawals** recorded the highest transaction volume and value, indicating a strong reliance on cash access.

### 2. Transaction Hotspots
```
select a.BranchCity, count(*) as Transaction_Volume from fact as j
inner join branch as a on j.branchcityid = a.branchcityid
group by a.BranchCity
order by Transaction_Volume desc
```

![Image](https://github.com/user-attachments/assets/23f09df7-9ff6-4a44-ab44-50b3cc1301c2)

* **Major urban branches** showed significantly higher transaction volumes.
* Cities like **Barcelona**, **Murcia**, and **Malaga** emerged as hotspots while cities like **Valencia**, and **Bilbao** emerged as underperformers.

### 3. Channel Usage Patterns
```
select d.Channel, Count(*) as transaction_frequency, round((count(*) * 100.0) / sum(count(*)) OVER (), 2) AS percentage_usage from fact as j
inner join channel as d on j.channelid = d.channelid
group by d.Channel
order by transaction_frequency desc
```

![Image](https://github.com/user-attachments/assets/98889ab3-6e43-4165-8b4c-76b844244455)
* While all channels have relatively balanced usage, **Mobile banking** edges ahead, highlighting a shift towards convenience-driven digital solutions. Traditional channels like **Branch and ATM** still retain substantial usage, reflecting a hybrid behavior among customers. 

---

## 💵 C. Revenue & Cost Insights

### 1. Transactions That Drive the Most Fees
```
select i.TransactionType, sum(fees) as Accumulated_fees from fact as J
inner join txn_type as i on j.transactiontypeid = i.transactiontypeid
group by i.TransactionType
order by Accumulated_fees desc
```
![Image](https://github.com/user-attachments/assets/b6f30614-b856-48fb-ae42-b2143e7f021b)

* **Loan Payments** generate the highest accumulated fees by a wide margin, indicating significant revenue from interest or processing charges tied to loans.
* **Withdrawals, Transfers, and Card Payments** also contribute considerable fees, suggesting these are high-frequency or high-cost services.
* **Deposits** incur the least fees, consistent with expectations, as deposits are typically low or no-cost services to encourage inflows.

### 2. Customer Groups With Disproportionate Costs
```
select h.CustomerSegment, count(fee_to_income) as Number_of_affected_customers
    from fact as j
    inner join segment as h on j.customersegmentid = h.customersegmentid where fee_to_income >0.15 
	group by h.CustomerSegment
```
![Image](https://github.com/user-attachments/assets/da866413-b48b-46af-b1b4-b55a5766da32)
```

select h.CustomerSegment, count(*) as Number_of_affected_customers
    from fact as j
    inner join segment as h on j.customersegmentid = h.customersegmentid where fee_to_amt > 0.15
	group by h.CustomerSegment
```
![Image](https://github.com/user-attachments/assets/7e241510-6250-495d-92fb-37d7e362cf6d)

* **Low-Income Customers** face a disproportionately high fee-to-income ratio, meaning a larger portion of their limited income goes toward transaction costs. This makes everyday banking relatively more expensive for the most financially vulnerable.
* Across all segments, many customers are also affected by a high fee-to-transaction amount ratio — with the **Middle-Income Segment** showing the highest number of affected users. This indicates inefficiency in the cost structure, where flat or uniform fees create unfair cost burdens, especially for smaller or moderate transactions.

### 3. Friction Points by Transaction Type
```
select i.TransactionType, count(*) as Transaction_volume
    from fact as j
   inner join txn_type as i on j.transactiontypeid = i.transactiontypeid where fee_to_income >0.15 
	group by i.transactiontype
```
![Image](https://github.com/user-attachments/assets/9f7451bf-5764-42c2-9f74-a55d21fd997f)
```

select i.TransactionType, count(*) as Transaction_volume
    from fact as j
   inner join txn_type as i on j.transactiontypeid = i.transactiontypeid where fee_to_amt >0.15 
	group by i.transactiontype
```
![Image](https://github.com/user-attachments/assets/4ab227b7-ca51-4c02-89fc-a245f1415c75)

* **Loan Payments** account for the highest number of frictions income wise and amount wise, This indicates a major performance and customer experience issue in the loan repayment process. **Transfers, Withdrawals, and Fee** transactions show moderate friction volumes while **Card Payments and Deposits** record the lowest friction volumes and friction rates, indicating that these channels are relatively efficient and reliable.

---

## 📈 D. Trend & Performance Analysis

### 1. Monthly Transaction Trends
```
select 
    year(f.transactiondate) as date_year,
    month(f.transactiondate) as date_month,
    count(*) as txn_count,
    sum(j.amt) as total_amount
from fact as j
inner join [date] as f on j.transactiondateid = f.transactiondateid
group by year(f.transactiondate), month(f.transactiondate)
order by txn_count desc, total_amount desc;
```

* Peaks observed in **December** and **March** — likely due to holidays and quarterly planning.
* Slower months: **July** and **August**, possibly reflecting mid-year lulls.

### 2. Offer Recommendations vs. Behavior
```
with matched_data as (
    select
        j.TransactionID,
        case
            when c.ProductSubcategory = 'student' and g.RecommendedOffer = 'financial literacy program access' then 'Accepted'
            when c.ProductSubcategory = 'gold' and g.RecommendedOffer = 'gold card with travel benefits' then 'Accepted'
            when c.ProductSubcategory = 'standard' and g.RecommendedOffer in ('mid-tier savings booster', 'no-fee basic account') then 'Accepted'
            when c.ProductSubcategory = 'business' and g.RecommendedOffer = 'personal loan cashback offer' then 'Accepted'
            when c.ProductSubcategory = 'platinum' and g.RecommendedOffer in ('premium investment services', 'exclusive platinum package') then 'Accepted'
            else 'Rejected'
        end as is_match
    from fact as J
	inner join offer as g on j.recommendedofferid = g.recommendedofferid
    inner join subcategory as c on j.productsubcategoryid = c.productsubcategoryid
)

select is_match, count(*) as Counts, round((count(*) * 100.0) / sum(count(*)) OVER (), 2) AS percentage_usage from matched_data group by is_match
```
* Matching analysis showed:

  * **\~70% of offers** were aligned with customer subcategory behavior.
  * Highest match success in **Platinum** and **Student** segments.
* Insight: Banks are doing fairly well in personalization but still have room for improvement.

### 3. Segment and Channel Performance Over Time
```
select h.customersegment, 
    year(f.transactiondate) as date_year,
    month(f.transactiondate) as date_month,
    count(*) as txn_count,
    sum(j.amt) as total_amount
from fact as j
inner join [date] as f on j.transactiondateid = f.transactiondateid
inner join segment as h on j.customersegmentid = h.customersegmentid
group by year(f.transactiondate), month(f.transactiondate),h.CustomerSegment
order by year(f.transactiondate), month(f.transactiondate)
```
```
select d.Channel, 
    year(f.transactiondate) as date_year,
    month(f.transactiondate) as date_month,
    count(*) as txn_count,
    sum(j.amt) as total_amount
from fact as j
inner join [date] as f on j.transactiondateid = f.transactiondateid
inner join channel as d on j.channelid = d.channelid
group by year(f.transactiondate), month(f.transactiondate),d.Channel
order by year(f.transactiondate), month(f.transactiondate)
```

* Segment-wise:

  * **Retail and Student** segments maintained steady growth.
  * **Corporate** had erratic performance with spikes around fiscal quarters.
* Channel-wise:

  * **Mobile** showed exponential growth.
  * **Branch** transactions declined over time, reinforcing digital migration.

---

## 📎 Key Metrics Created

| Metric          | Description                                    |
| --------------- | ---------------------------------------------- |
| `Amt`           | Standardized transaction amount in EUR         |
| `Fees`          | Sum of penalty-related charges                 |
| `Income`        | Monthly income normalized to EUR               |
| `Fee_to_amt`    | Fee cost burden relative to transaction amount |
| `Fee_to_income` | Fee burden as a share of income                |

---

## ✅ Recommendations

* **Review fee policies** for low-income and SME segments to prevent churn.
* **Promote mobile banking features** with targeted campaigns in high-usage months.
* **Adjust product offers** in real-time using past subcategory behaviors.
* **Deploy more ATMs** in cities with high transaction volume but low branch density.

---

