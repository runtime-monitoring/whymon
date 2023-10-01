import React from 'react';
import Typography from '@mui/material/Typography';
import Box from '@mui/material/Box';
import ArrowRightIcon from '@mui/icons-material/ArrowRight';
import MenuItem from '@mui/material/MenuItem';
import WrapperNestedMenuItem from './WrapperNestedMenuItem';
import WrapperIconMenuItem from './WrapperIconMenuItem';

function MenuInstance ({ explObj, curCol, open, domainValues, variableNames, handleClose, handleClick }) {

  if (explObj.type === "node" || explObj.kind === "partition") {
    const newVariableNames = [];

    newVariableNames.push(...variableNames);
    newVariableNames.push(explObj.var);

    return (
      <div>
        <Box sx={{ ml: 1, mr: 1, mb: 1, borderRadius: '9px' }}
             style={{ color: "#FFFFFF",
                      opacity: 1.0,
                      background: "#000000" }}>
          <MenuItem disabled={true}
                    sx={{ justifyContent: 'center' }}
                    style={{ opacity: 1.0 }}>
            <Typography variant="h6">{explObj.var}</Typography>
          </MenuItem>
        </Box>
        { explObj?.part?.map((el, i) => {

          const domainValueLabel = el.subset_type === "finite" ?
                el.subset_values.join(', ') : (<span style={{fontWeight: 'bold'}}>Other</span>);
          let domainValue = el.subset_type === "finite" ?
              el.subset_values.join(', ') : "∁ {".concat(el.subset_values.join(', ')).concat("}");
          if (el.subset_values.length === 0) domainValue = "𝔻";

          const newDomainValues = [];
          newDomainValues.push(...domainValues);
          newDomainValues.push(domainValue);

          if (el.type === "node" || el.kind === "partition") {
            return (
              <div key={i}>
                <WrapperNestedMenuItem rightIcon={<ArrowRightIcon/>}
                                       label={domainValueLabel}
                                       explObj={el}
                                       curCol={curCol}
                                       parentMenuOpen={open}>
                  <MenuInstance explObj={el}
                                curCol={curCol}
                                open={open}
                                domainValues={newDomainValues}
                                variableNames={newVariableNames}
                                handleClose={handleClose}
                                handleClick={handleClick}/>
                </WrapperNestedMenuItem>
              </div>
            );
          } else {
            return (
              <div key={i}>
                <WrapperIconMenuItem label={domainValueLabel}
                                     explObj={el}
                                     curCol={curCol}
                                     domainValues={newDomainValues}
                                     variableNames={newVariableNames}
                                     handleClick={handleClick}/>
              </div>
            );
          }
        })}
      </div>
    );
  } else {
    return "";
  }
}

export default MenuInstance;
