-- Create the EmployeeDemographics table
CREATE TABLE IF NOT EXISTS datasets.EmployeeDemographics (
    EmployeeID SERIAL PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Age INT,
    Gender VARCHAR(50)
);

CREATE INDEX IF NOT EXISTS idx_employee_demographics_name 
    ON datasets.EmployeeDemographics(FirstName, LastName);

-- Create the EmployeeSalary table
CREATE TABLE IF NOT EXISTS datasets.EmployeeSalary (
    EmployeeID INT REFERENCES datasets.EmployeeDemographics(EmployeeID),
    JobTitle VARCHAR(50),
    Salary INT
);

CREATE INDEX IF NOT EXISTS idx_employee_salary_jobtitle 
    ON datasets.EmployeeSalary(JobTitle);




-- Insert data into EmployeeDemographics
INSERT INTO datasets.EmployeeDemographics (FirstName, LastName, Age, Gender) VALUES
('Jim', 'Halpert', 30, 'Male'),
('Pam', 'Beasley', 30, 'Female'),
('Dwight', 'Schrute', 29, 'Male'),
('Angela', 'Martin', 31, 'Female'),
('Toby', 'Flenderson', 32, 'Male'),
('Michael', 'Scott', 35, 'Male'),
('Meredith', 'Palmer', 32, 'Female'),
('Stanley', 'Hudson', 38, 'Male'),
('Kevin', 'Malone', 31, 'Male');

-- Insert data into EmployeeSalary
INSERT INTO datasets.EmployeeSalary (EmployeeID, JobTitle, Salary) VALUES
(1, 'Salesman', 45000),
(2, 'Receptionist', 36000),
(3, 'Salesman', 63000),
(4, 'Accountant', 47000),
(5, 'HR', 50000),
(6, 'Regional Manager', 65000),
(7, 'Supplier Relations', 41000),
(8, 'Salesman', 48000),
(9, 'Accountant', 42000);
